/// The merge-safe update: success, every failure code, rollback, audit and lock timeout.
Class PatientRegistry.Tests.MergeUpdateTest Extends PatientRegistry.Tests.TestBase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
    Set sc = ##super(testname)
    Set p = ..NewPatient()
    Quit p.%Save()
}

Method TestSuccessIncrementsVersionAndAppliesOnlyTheChange()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"Dani"}, 1, .version)
    Do $$$AssertStatusOK(sc, "the update succeeds")
    Do $$$AssertEquals(version, 2, "the version is incremented")
    Set p = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
    Do $$$AssertEquals(p.GivenName, "Dani", "the given name changed")
    Do $$$AssertEquals(p.FamilyName, "TestFamily", "an absent field is left untouched (merge-patch)")
    Do $$$AssertEquals(p.AdministrativeSex, "F", "another absent field is left untouched")
}

Method TestIdentityIsCaseInsensitive()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("synth-hosp-a", "10000016", {"givenName":"Case"}, "", .version)
    Do $$$AssertStatusOK(sc, "a lower-case identity addresses the same patient")
}

Method TestStaleVersionIsRefused()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"First"}, 1, .version)
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"Late"}, 1, .version)
    Do ..AssertFailedWith(sc, "PR-VERSION-CONFLICT")
    Set p = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
    Do $$$AssertEquals(p.GivenName, "First", "the stale update did not overwrite the newer change")
}

Method TestIdentityCannotBeChanged()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"mrn":"99999999"}, "", .version)
    Do ..AssertFailedWith(sc, "PR-IDENTITY-IMMUTABLE")
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"assigningAuthority":"OTHER"}, "", .version)
    Do ..AssertFailedWith(sc, "PR-IDENTITY-IMMUTABLE")
}

Method TestUnknownPatientIsNotFound()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "99999994", {"givenName":"Nobody"}, "", .version)
    Do ..AssertFailedWith(sc, "PR-NOT-FOUND")
}

Method TestEmptyOrMalformedChangesAreRefused()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"version":99,"createdAt":"x"}, "", .version)
    Do ..AssertFailedWith(sc, "PR-INVALID-INPUT")
    Set p = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
    Do $$$AssertEquals(p.Version, 1, "read-only fields cannot be set through an update")
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", "not an object", "", .version)
    Do ..AssertFailedWith(sc, "PR-INVALID-INPUT")
}

Method TestInvalidValueIsRefusedAndNothingChanges()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"administrativeSex":"X"}, "", .version)
    Do $$$AssertStatusNotOK(sc, "an invalid sex code is refused")
    Set p = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
    Do $$$AssertEquals(p.AdministrativeSex, "F", "the stored value is unchanged")
    Do $$$AssertEquals(p.Version, 1, "the version is unchanged")
    Do $$$AssertEquals($TLEVEL, 0, "no transaction was left open")
}

Method TestRollbackLeavesNoTrace()
{
    Set ^||PatReg.FailAfterSave = 1
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"ShouldNotStick"}, "", .version)
    Kill ^||PatReg.FailAfterSave
    Do ..AssertFailedWith(sc, "PR-INJECTED")
    Set p = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
    Do $$$AssertEquals(p.GivenName, "Alex", "the saved change was rolled back")
    Do $$$AssertEquals(p.Version, 1, "the version increment was rolled back")
    Do $$$AssertEquals($ORDER(^PatReg.Audit("")), "", "no audit record was written")
    Do $$$AssertEquals($TLEVEL, 0, "no transaction was left open")
}

Method TestAuditRecordsFieldNamesNeverValues()
{
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"Secretvalue"}, "", .version)
    Set n = $ORDER(^PatReg.Audit(""))
    Do $$$AssertTrue(n '= "", "an audit record exists")
    Set record = ^PatReg.Audit(n)
    Do $$$AssertEquals($LISTGET(record, 4), "MergeUpdate", "the action is recorded")
    Do $$$AssertEquals($LISTGET(record, 5), "givenName", "only the field NAME is recorded")
    Do $$$AssertEquals($LISTGET(record, 3), 2, "the new version is recorded")
    Do $$$AssertTrue('($LISTTOSTRING(record) [ "Secretvalue"), "the changed VALUE is not in the audit trail")
}

Method TestNestedTransactionIsRefused()
{
    Tstart
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"Nested"}, "", .version)
    Trollback
    Do ..AssertFailedWith(sc, "PR-NESTED-TRANSACTION")
}

Method TestLockTimeout()
{
    Job ##class(PatientRegistry.Tests.MergeUpdateTest).HoldLock("SYNTH-HOSP-A", "10000016", 3)
    Do ..WaitForFlag("locked")
    Do $$$AssertEquals($GET(^PatReg.TestFlag("locked")), 1, "the background job holds the lock")
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"Blocked"}, "", .version, 1)
    Do ..AssertFailedWith(sc, "PR-LOCK-TIMEOUT")
    Set p = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
    Do $$$AssertEquals(p.GivenName, "Alex", "a timed-out update changed nothing")
    Do ..WaitForFlag("released")
    Set sc = ##class(PatientRegistry.Service.PatientService).MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName":"After"}, "", .version, 1)
    Do $$$AssertStatusOK(sc, "once the lock is released the update succeeds")
}

/// Runs in a background process: holds the identity lock, then releases it.
ClassMethod HoldLock(pAuthority As %String, pMRN As %String, pSeconds As %Integer)
{
    Lock +^PatReg.PatientLock(pAuthority, pMRN):5
    If $TEST {
        Set ^PatReg.TestFlag("locked") = 1
        Hang pSeconds
        Lock -^PatReg.PatientLock(pAuthority, pMRN)
    }
    Set ^PatReg.TestFlag("released") = 1
}

/// Waits up to 8 seconds for a flag set by the background job.
Method WaitForFlag(pFlag As %String)
{
    For i = 1:1:80 {
        If $GET(^PatReg.TestFlag(pFlag)) {
            Quit
        }
        Hang 0.1
    }
}

}
