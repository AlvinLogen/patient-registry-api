Class PatientRegistry.Tests.PatientTest Extends PatientRegistry.Tests.TestBase
{
    Method TestSaveValidPatient()
    {
        Set p = ..NewPatient()
        Set sc = p.%Save()
        Do $$$AssertStatusOK(sc, "a valid patient saves")
        Do $$$AssertTrue(p.%Id() '= "", "an ID is assigned")
        Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), 1, "exactly one patient exists")
    }

    Method TestUniqueIdentifier() 
    {
        Set first = ..NewPatient("SYNTH-HOSP-A", "10000016")
        Set sc = first.%Save()
        Do $$$AssertStatusOK(sc, "the first patient saves")
        Set duplicate = ..NewPatient("synth-hosp-a", "10000016")
        Set sc = duplicate.%Save()
        Do $$$AssertStatusNotOK(sc, "the same identity is refused, even in lower case")
        Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), 1, "still exactly one patient")
    }

    Method TestSameMrnDifferentAuthority()
    {
        Set a = ..NewPatient("SYNTH-HOSP-A", "10000016")
        Set b = ..NewPatient("SYNTH-LAB-B", "10000016")
        Set scA = a.%Save()
        Set scB = b.%Save()
        Do $$$AssertStatusOK(scA, "auhority A saves")
        Do $$$AssertStatusOK(scB, "the same MRN under authority B is a different identity")
    }

    Method TestRequiredFields()
    {
        Set p = ..NewPatient()
        Set p.FamilyName = ""
        Set sc = p.%Save()
        Do $$$AssertStatusNotOK(sc, "FamilyName is required")
        Set q = ..NewPatient()
        Set q.MRN = ""
        Set sc = q.%Save()
        Do $$$AssertStatusNotOK(sc, "MRN is required")
    }

    Method TestInvalidValuesAreRefused()
    {
        Set p = ..NewPatient()
        Set p.AdministrativeSex = "X"
        Set sc = p.%Save()
        Do $$$AssertStatusNotOK(sc, "an unknown sex code is refused")
        Set q = ..NewPatient()
        Set q.MRN = "10-00!"
        Set sc = q.%Save()
        Do $$$AssertStatusNotOK(sc, "an MRN with punctuation is refused")
    }

    Method TestFindByIdentier()
    {
        Set p = ..NewPatient()
        Set sc = p.%Save()
        Set found = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "10000016")
        Do $$$AssertEquals($ISOBJECT(found), 1, "an existing identity is found")
        Do $$$AssertEquals(found.FullName(), "Alex TestFamily", "FullName combines given and family name")
        Set miss = ##class(PatientRegistry.Model.Patient).FindByIdentifier("SYNTH-HOSP-A", "NOPE")
        Do $$$AssertEquals($ISOBJECT(miss), 0, "an unknown identity returns an empty value, not an object")
    }

    Method TestAuditTimestamps()
    {
        Set p = ..NewPatient()
        Set sc = p.%Save()
        Do $$$AssertTrue(p.CreatedAt ? 4N1"-"2N1"-"2N1" "2N1":"2N1":"2N1"."1.N, "CreatedAt is a UTC timestamp")
        Set created = p.CreatedAt
        Set p.GivenName = "Alexa"
        Set sc = p.%Save()
        Do $$$AssertEquals(p.CreatedAt, created, "CreatedAt never changes after the first save")
        Do $$$AssertTrue(p.UpdatedAt '= "", "UpdatedAt is set on every save")
    }

    Method TestAddressIsStoredInsideThePatient()
    {
        Set p = ..NewPatient()
        Set p.HomeAddress = ##class(PatientRegistry.Model.Address).%New()
        Set p.HomeAddress.City = "Testville"
        Set sc = p.%Save()
        Do $$$AssertStatusOK(sc, "a patient with an address saves")
        Set reopened = ##class(PatientRegistry.Model.Patient).%OpenId(p.%Id())
        Do $$$AssertEquals(reopened.HomeAddress.City, "Testville", "the serial address round-trips")
        Do $$$AssertEquals(reopened.HomeAddress.Country, "ZA", "the default country applies")
    }
}
