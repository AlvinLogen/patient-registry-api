/// Shared set-up for every suite. Each test starts from an EMPTY registry Safe only in a disposable namespace: it calls %KillExtent().
Class PatientRegistry.Tests.TestBase Extends %UnitTest.TestCase [ Abstract ]
{
    Parameter FIXTUREDIR = "/home/irisowner/dev/fixtures/";

    Method OnBeforeOneTest(testname As %String) As %Status
    {
        Kill ^||PatReg.FailAfterSave
        Kill ^PatReg.Audit
        Kill ^PatReg.TestFlag
        Do ##class(PatientRegistry.Model.Patient).%KillExtent()
        Quit $$$OK
    }

    /// A valid, UNSAVED patient. Synethetic values only.
    ClassMethod NewPatient(pAuthority As %String = "SYNTH-HOSP-A", pMRN As %String = "10000016") As PatientRegistry.Model.Patient
    {
        Set p = ##class(PatientRegistry.Model.Patient).%New()
        Set p.AssigningAuthority = pAuthority
        Set p.MRN = pMRN
        Set p.FamilyName = "TestFamily"
        Set p.GivenName = "Alex"
        Set p.BirthDate = $ZDATEH("1980-02-14", 3)
        Set p.AdministrativeSex = "F"
        Quit p
    }


    /// Asserts that pStatus is an error whose text carries the stable code pCode.
    Method AssertFailedWith(pStatus As %Status, pCode As %String)
    {
        Do $$$AssertStatusNotOK(pStatus, "the operation failed ("_pCode_")")
        Do $$$AssertTrue($SYSTEM.Status.GetErrorText(pStatus) [pCode, "the error carries the code "_pCode)
    }
}
