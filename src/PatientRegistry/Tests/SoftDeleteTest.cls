Class PatientRegistry.Tests.SoftDeleteTest Extends PatientRegistry.Tests.TestBase
{
    Method OnBeforeOneTest(testname As %String) As %Status
    {
        Set sc = ##super(testname)
        Quit:$$$ISERR(sc) sc
        Set p = ..NewPatient()
        Quit p.%Save()
    }

    Method TestDeactivateHidesFromSearchButKeepsTheRecord()
    {
        Set sc = ##class(PatientRegistry.Model.Patient).CountByFamilyName("Testfamily", .n)
        Do $$$AssertEquals(n, 1, "the active patient is found")

        Set sc = ##class(PatientRegistry.Service.PatientService).Deactivate("SYNTH-HOSP-A", "10000016", 1, .version)
        Do $$$AssertStatusOK(sc, "deactivation succeeds")
        Do $$$AssertEquals(version, 2, "deactivation is a versioned change")

        Set sc = ##class(PatientRegistry.Model.Patient).CountByFamilyName("Testfamily", .n)
        Do $$$AssertEquals(n, 0, "an inactive patient is excluded from search")

        Set found = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
        Do $$$AssertEquals($ISOBJECT(found), 1, "the record still exists")
        Do $$$AssertEquals(found.Active, 0, "and i is marked inactive")
    }

    Method TestIdentityStaysReservedAfterDeactivation()
    {
        Set sc = ##class(PatientRegistry.Service.PatientService).Deactivate("SYNTH-HOSP-A", "10000016")
        Set again = ..NewPatient("SYNTH-HOSP-A", "10000016")
        Set sc = again.%Save()
        Do $$$AssertStatusNotOK(sc, "an inactive patient still owns its identity")
    }

    Method TestReactivateRestoreSearchability()
    {
        Set sc = ##class(PatientRegistry.Service.PatientService).Deactivate("SYNTH-HOSP-A", "10000016")
        Set sc = ##class(PatientRegistry.Service.PatientService).Reactivate("SYNTH-HOSP-A", "10000016", 2, .version)
        Do $$$AssertStatusOK(sc, "reactivation succeeds")
        Do $$$AssertEquals(version, 3, "two versioned changes so far")

        Set sc = ##class(PatientRegistry.Model.Patient).CountByFamilyName("Testfamily", .n)
        Do $$$AssertEquals(n, 1, "the patient is searchable again")
    }

    Method TestDeactivationIsAudited()
    {
        Set sc = ##class(PatientRegistry.Service.PatientService).Deactivate("SYNTH-HOSP-A", "10000016")
        Set record = ^PatReg.Audit($ORDER(^PatReg.Audit("")))
        Do $$$AssertEquals($LISTGET(record, 5), "active", "the audit trail names the changed field")
    }

    Method TestHardDeleteRefused()
    {
        Set id = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016").%Id()
        Set sc = ##class(PatientRegistry.Model.Patient).%DeleteId(id)

        Do ..AssertFailedWith(sc, "PR-HARD-DELETE-FORBIDDEN")
        Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), 1, "the patient still exists")
    }
}
