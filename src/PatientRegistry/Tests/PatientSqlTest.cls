/// Host-variable queries: correctness, case-insensitivity and injection resistance.
Class PatientRegistry.Tests.PatientSqlTest Extends PatientRegistry.Tests.TestBase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
    Set sc = ##super(testname)
    Set a = ..NewPatient("SYNTH-HOSP-A", "MRN0001")
    Set sc = a.%Save()
    Set b = ..NewPatient("SYNTH-HOSP-A", "MRN0002")
    Set sc = b.%Save()
    Set other = ..NewPatient("SYNTH-HOSP-A", "MRN0003")
    Set other.FamilyName = "Otherfamily"
    Set sc = other.%Save()
    Set inactive = ..NewPatient("SYNTH-HOSP-A", "MRN0004")
    Set inactive.Active = 0
    Quit inactive.%Save()
}

Method TestCountCountsOnlyActivePatientsWithThatName()
{
    Set sc = ##class(PatientRegistry.Model.Patient).CountByFamilyName("Testfamily", .n)
    Do $$$AssertStatusOK(sc, "the count query runs")
    Do $$$AssertEquals(n, 2, "two ACTIVE patients are named Testfamily (the inactive one is excluded)")
}

Method TestMatchingIgnoresCase()
{
    Set sc = ##class(PatientRegistry.Model.Patient).CountByFamilyName("TESTFAMILY", .n)
    Do $$$AssertEquals(n, 2, "the comparison is case-insensitive")
}

Method TestHostVariablesResistInjection()
{
    Set sc = ##class(PatientRegistry.Model.Patient).CountByFamilyName("x' OR '1'='1", .n)
    Do $$$AssertStatusOK(sc, "the query runs with a hostile value")
    Do $$$AssertEquals(n, 0, "the hostile text is treated as a value and matches nothing")
    Set sc = ##class(PatientRegistry.Model.Patient).FindByFamilyName("Testfamily'; DROP TABLE x; --", .result)
    Do $$$AssertEquals(result.%Size(), 0, "a second hostile value also matches nothing")
    Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), 4, "all four patients still exist")
}

Method TestFindReturnsCanonicalJson()
{
    Set sc = ##class(PatientRegistry.Model.Patient).FindByFamilyName("Testfamily", .result)
    Do $$$AssertStatusOK(sc, "the find query runs")
    Do $$$AssertEquals(result.%Size(), 2, "two active matches")
    Set first = result.%Get(0)
    Do $$$AssertEquals(first.%GetTypeOf("mrn"), "string", "mrn is a JSON string")
    Do $$$AssertEquals(first.mrn, "MRN0001", "results are ordered by ID")
}

}
