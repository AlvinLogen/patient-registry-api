Class PatientRegistry.Tests.PatientTest Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
    Quit ##class(PatientRegistry.Patient).%DeleteExtent()
}

Method OnAfterOneTest(testname As %String) As %Status
{
    Quit ##class(PatientRegistry.Patient).%DeleteExtent()
}

Method TestIdentity()
{
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","givenName":"Synthetic"}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id))
    Do $$$AssertTrue(id'="", "New patient has an ID")
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).FromJSON(data, .duplicate))
    Do $$$AssertStatusNotOK(duplicate.%Save(), "Duplicate composite identity is rejected")
    Do data.%Set("assigningAuthority", "OTHER")
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .otherID))
    Do $$$AssertTrue(otherID'=id, "The same MRN belongs to different authorities")
    Do data.%Set("assigningAuthority", "synthetic")
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .caseID))
    Do $$$AssertTrue(caseID'=id, "Authority identity is case-sensitive")
}

Method TestJSONRoundTrip()
{
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","givenName":"Synthetic","familyName":"Patient","address":{"line1":"1 Example Street","city":"Example City","postalCode":"00000","country":"ZZ"}}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id))
    Set patient = ##class(PatientRegistry.Patient).%OpenId(id)
    Set exported = patient.ToJSON()
    Do $$$AssertEquals(exported.%Get("mrn"), "000000018", "Leading zeroes survive persistence")
    Do $$$AssertEquals(exported.%Get("address").%Get("city"), "Example City")
    Set reparsed = ##class(%DynamicObject).%FromJSON(exported.%ToJSON())
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).FromJSON(reparsed, .copy))
    Do $$$AssertEquals(copy.GivenName, "Synthetic")
    Do $$$AssertEquals(copy.Address.PostalCode, "00000")
}

Method TestMergePreservesOmittedFields()
{
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","givenName":"Synthetic","familyName":"Patient","address":{"line1":"1 Example Street","city":"Old City","country":"ZZ"}}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id))
    Set patch = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","familyName":"Updated","address":{"city":"New City"}}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(patch, .updatedID))
    Do $$$AssertEquals(updatedID, id)
    Set patient = ##class(PatientRegistry.Patient).%OpenId(id)
    Do $$$AssertEquals(patient.GivenName, "Synthetic")
    Do $$$AssertEquals(patient.FamilyName, "Updated")
    Do $$$AssertEquals(patient.Address.Line1, "1 Example Street")
    Do $$$AssertEquals(patient.Address.City, "New City")
    Do $$$AssertEquals(patient.Address.Country, "ZZ")
    Set patient = ""
    Set clear = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","address":null}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(clear, .updatedID))
    Set patient = ##class(PatientRegistry.Patient).%OpenId(id)
    Do $$$AssertTrue(patient.Address.%IsNull(), "Explicit null clears the embedded address")
    Do $$$AssertEquals(patient.ToJSON().%GetTypeOf("address"), "null")
}

Method TestRollbackAndUnlock()
{
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","givenName":"Synthetic"}
    Do $$$AssertStatusOK(##class(PatientRegistry.Tests.RejectingPatient).MergeSafeUpdate(data, .id))
    Set patch = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","familyName":"REJECT","address":{"city":"Example City"}}
    Do $$$AssertStatusNotOK(##class(PatientRegistry.Tests.RejectingPatient).MergeSafeUpdate(patch, .failedID))
    Do $$$AssertEquals(failedID, "")
    Do $$$AssertEquals($TLevel, 0, "Failed save rolled back its transaction")
    Set patient = ##class(PatientRegistry.Patient).%OpenId(id)
    Do $$$AssertEquals(patient.FamilyName, "")
    Do $$$AssertTrue(patient.Address.%IsNull(), "Failed update did not persist the address")
    Set patient = ""
    Do patch.%Set("familyName", "Updated")
    Do $$$AssertStatusOK(##class(PatientRegistry.Tests.RejectingPatient).MergeSafeUpdate(patch, .updatedID, 0))
    Do $$$AssertEquals(updatedID, id)
}

Method TestCachedObjectRefresh()
{
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","givenName":"Synthetic"}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id))
    Set cached = ##class(PatientRegistry.Patient).%OpenId(id)
    Set cached.GivenName = "Unsaved"
    Set patch = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","familyName":"Updated"}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(patch, .updatedID))
    Do $$$AssertEquals(cached.GivenName, "Synthetic", "Merge refreshes cached objects from persistent state")
    Do $$$AssertEquals(cached.FamilyName, "Updated")
}

Method TestLockTimeout()
{
    Kill ^PatientRegistry.TestLock
    Job ##class(PatientRegistry.Tests.PatientTest).LockHolder()
    Set ready = 0
    For i = 1:1:100 {
        If $Get(^PatientRegistry.TestLock("ready")) Set ready = 1 Quit
        Hang .1
    }
    If 'ready {
        Set ^PatientRegistry.TestLock("release") = 1
        Do $$$AssertTrue(ready, "Lock holder started")
        Quit
    }
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018"}
    Set sc = ##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id, 0)
    Set ^PatientRegistry.TestLock("release") = 1
    For i = 1:1:100 {
        If $Get(^PatientRegistry.TestLock("done")) Quit
        Hang .1
    }
    Do $$$AssertStatusNotOK(sc, "A different process holds the identity lock")
    Do $$$AssertEquals(id, "")
    Do $$$AssertEquals($TLevel, 0)
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id, 0))
    Kill ^PatientRegistry.TestLock
}

ClassMethod LockHolder()
{
    Lock +^PatientRegistry.Lock("SYNTHETIC", "000000018"):5
    If '$Test Quit
    Set ^PatientRegistry.TestLock("ready") = 1
    For i = 1:1:200 {
        If $Get(^PatientRegistry.TestLock("release")) Quit
        Hang .1
    }
    Lock -^PatientRegistry.Lock("SYNTHETIC", "000000018")
    Set ^PatientRegistry.TestLock("done") = 1
}

Method TestInvalidJSON()
{
    Set missing = {"givenName":"Synthetic"}
    Do $$$AssertStatusNotOK(##class(PatientRegistry.Patient).MergeSafeUpdate(missing, .id))
    Set numericMRN = {"assigningAuthority":"SYNTHETIC","mrn":18}
    Do $$$AssertStatusNotOK(##class(PatientRegistry.Patient).MergeSafeUpdate(numericMRN, .id))
    Set invalidAddress = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","address":[]}
    Do $$$AssertStatusNotOK(##class(PatientRegistry.Patient).MergeSafeUpdate(invalidAddress, .id))
    Set invalidName = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","familyName":null}
    Do $$$AssertStatusNotOK(##class(PatientRegistry.Patient).MergeSafeUpdate(invalidName, .id))
    Set invalidCity = {"assigningAuthority":"SYNTHETIC","mrn":"000000018","address":{"country":42}}
    Do $$$AssertStatusNotOK(##class(PatientRegistry.Patient).MergeSafeUpdate(invalidCity, .id))
}

Method TestHostVariables()
{
    Set data = {"assigningAuthority":"SYNTHETIC' OR 1=1 --","mrn":"000000018"}
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id))
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).FindByIdentity("SYNTHETIC", "000000018", .missingID))
    Do $$$AssertEquals(missingID, "", "SQL metacharacters are literal identity data")
    Do $$$AssertStatusOK(##class(PatientRegistry.Patient).FindByIdentity(data.%Get("assigningAuthority"), data.%Get("mrn"), .foundID))
    Do $$$AssertEquals(foundID, id)
}

Method TestTransactionBoundary()
{
    Set data = {"assigningAuthority":"SYNTHETIC","mrn":"000000018"}
    TStart
    Set sc = ##class(PatientRegistry.Patient).MergeSafeUpdate(data, .id)
    Set level = $TLevel
    TRollback
    Do $$$AssertStatusNotOK(sc, "An outer transaction must not outlive the identity lock")
    Do $$$AssertEquals(level, 1, "The caller's transaction is untouched")
}

Method TestCheckDigit()
{
    Do $$$AssertEquals(##class(PatientRegistry.Patient).CheckDigit("7992739871"), "3")
    Do $$$AssertEquals(##class(PatientRegistry.Patient).CheckDigit("12345"), "5")
    Do $$$AssertEquals(##class(PatientRegistry.Patient).CheckDigit("00000001"), "8")
    Set rejected = 0
    Try {
        Set digit = ##class(PatientRegistry.Patient).CheckDigit("12A")
    } Catch exception {
        Set rejected = 1
    }
    Do $$$AssertTrue(rejected, "Embedded Python rejects nonnumeric MRNs")
}

}
