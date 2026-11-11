Class PatientRegistry.Tests.ImportExportTest Extends PatientRegistry.Tests.TestBase
{
    Method TestImportFixtureFile()
    {
        Set path = ..#FIXTUREDIR
        Set path = path_"generated/patients.json"
        Set expected = ##class(%DynamicAbstractObject).%FromJSONFile(path).meta.count
        Set sc = ##class(PatientRegistry.Service.PatientService).ImportFile(path, .count)
        Do $$$AssertStatusOK(sc, "the generated fixture file imports")
        Do $$$AssertTrue(expected > 0, "the fixture declares at least one patient")
        Do $$$AssertEquals(count, expected, "every declared patient was imported")
        Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), expected, "the registry holds them all")
    }

    Method TestImportIsAllOrNothing()
    {
        Set path = ..#FIXTUREDIR
        Set path = path_"generated/patients.json"
        Set sc = ##class(PatientRegistry.Service.PatientService).ImportFile(path, .count)
        Set total = ##class(PatientRegistry.Service.PatientService).Count()
        Set sc = ##class(PatientRegistry.Service.PatientService).ImportFile(path, .count)
        Do ..AssertFailedWith(sc, "PR-IMPORT-REJECTED")
        Do $$$AssertEquals(count, 0, "a rejected imported reports zero rows imported")
        Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), total, "the registry is unchanged")
    }

    Method TestRowFailureRollsBackEarlierRows()
    {
        Set row = {"assigningAuthority": "SYNTH-HOSP-A", "mrn": "10000016", "familyName": "Rowone", "givenName": "Test"}
        Set document = {"data": []}
        Do document.data.%Push(row)
        Do document.data.%Push(row)
        Set sc = ##class(PatientRegistry.Service.PatientService).ImportDocument(document, .count)
        Do ..AssertFailedWith(sc, "PR-IMPORT-REJECTED")
        Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), 0, "the valid first row was rolled back")
    }

Method TestRoundTrip()
{
    Set path = ..#FIXTUREDIR
    Set path = path_"generated/patients.json"
    Set sc = ##class(PatientRegistry.Service.PatientService).ImportFile(path, .count)
    Set sc = ##class(PatientRegistry.Service.PatientService).ExportAll(.first)
    Do $$$AssertStatusOK(sc, "the registry exports")
    Do ##class(PatientRegistry.Model.Patient).%KillExtent()
    Set sc = ##class(PatientRegistry.Service.PatientService).ImportDocument(first, .count)
    Do $$$AssertStatusOK(sc, "the exported document imports again")
    Set sc = ##class(PatientRegistry.Service.PatientService).ExportAll(.second)
    Set mismatches = 0
    Set iter = first.data.%GetIterator()
    While iter.%GetNext(.key, .a) {
        Set b = second.data.%Get(key)
        If (a.assigningAuthority '= b.assigningAuthority) || (a.mrn '= b.mrn) || (a.familyName '= b.familyName) || (a.givenName '= b.givenName) || (a.birthDate '= b.birthDate) || (a.administrativeSex '= b.administrativeSex) || (a.active '= b.active) || (a.homeAddress.%ToJSON() '= b.homeAddress.%ToJSON()) {
            Set mismatches = mismatches + 1
        }
    }
    Do $$$AssertEquals(second.data.%Size(), first.data.%Size(), "the same number of patients")
    Do $$$AssertEquals(mismatches, 0, "no patient changed in the round trip")
}

Method TestExportTypesAreCorrect()
{
    Set p = ..NewPatient()
    Set p.HomeAddress = ##class(PatientRegistry.Model.Address).%New()
    Set p.HomeAddress.PostalCode = "1000"
    Set sc = p.%Save()
    Set sc = ##class(PatientRegistry.Service.PatientService).ExportAll(.document)
    Set row = document.data.%Get(0)
    Do $$$AssertEquals(row.%GetTypeOf("mrn"), "string", "mrn is a JSON string")
    Do $$$AssertEquals(row.homeAddress.%GetTypeOf("postalCode"), "string", "a numeric-looking postal code stays a string")
    Do $$$AssertEquals(row.%GetTypeOf("active"), "boolean", "active is a JSON boolean")
    Do $$$AssertEquals(row.%GetTypeOf("version"), "number", "version is a JSON number")
    Do $$$AssertTrue(row.createdAt ? 4N1"-"2N1"-"2N1"T"2N1":"2N1":"2N1"."1.N1"Z", "createdAt is ISO 8601 UTC")
}

Method TestRejectsBadInput()
{
    Set numeric = {"data":[{"assigningAuthority":"SYNTH-HOSP-A","mrn":12345674,"familyName":"X","givenName":"Y"}]}
    Set sc = ##class(PatientRegistry.Service.PatientService).ImportDocument(numeric, .count)
    Do ..AssertFailedWith(sc, "PR-IMPORT-REJECTED")
    Set notArray = {"data":{"a":1}}
    Set sc = ##class(PatientRegistry.Service.PatientService).ImportDocument(notArray, .count)
    Do ..AssertFailedWith(sc, "PR-INVALID-INPUT")
    Set sc = ##class(PatientRegistry.Service.PatientService).ImportFile("/home/irisowner/dev/fixtures/../src/x.json", .count)
    Do ..AssertFailedWith(sc, "PR-INVALID-INPUT")
    Set sc = ##class(PatientRegistry.Service.PatientService).ImportFile("/etc/passwd", .count)
    Do ..AssertFailedWith(sc, "PR-INVALID-INPUT")
    Do $$$AssertEquals(##class(PatientRegistry.Service.PatientService).Count(), 0, "nothing was imported")
}
}
