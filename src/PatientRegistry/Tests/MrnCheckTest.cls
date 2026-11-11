Class PatientRegistry.Tests.MrnCheckTest Extends PatientRegistry.Tests.TestBase
{
    Parameter VECTORS = "/home/irisowner/dev/fixtures/vectors/mrn-check-digit.json";

    Method TestSharedVectors()
    {
        Set vectors = ##class(%DynamicAbstractObject).%FromJSONFile(..#VECTORS)
        Set iter = vectors.valid.%GetIterator()
        Set checked = 0
        While iter.%GetNext(.key, .vector) {
            Set digit = ##class(PatientRegistry.Util.MrnCheck).CheckDigit(vector.payload)
            Do $$$AssertEquals(digit, vector.checkDigit, "check digit for payload "_vector.payload)
            Set valid = ##class(PatientRegistry.Util.MrnCheck).IsValid(vector.payload_vector.checkDigit)
            Do $$$AssertEquals(valid, 1, "payload plus check digit is a valid MRN: "_vector.payload)
            Set checked = checked + 1
        }
        Do $$$AssertTrue(checked >= 5, "all documented vectors were exercised")
    }

    Method TestInvalidMrnsAreRejected()
    {
        Set vectors = ##class(%DynamicAbstractObject).%FromJSONFile(..#VECTORS)
        Set iter = vectors.invalidMrns.%GetIterator()
        While iter.%GetNext(.key, .mrn) {
            Do $$$AssertEquals(##class(PatientRegistry.Util.MrnCheck).IsValid(mrn), 0, "invalid MRN #"_(key + 1)_" is rejected")
        }
    }

    Method TestPythonErrorBecomesAnObjectScriptException()
    {
        Set caught = 0
        Try {
            Set digit = ##class(PatientRegistry.Util.MrnCheck).CheckDigit("12a4")
        } Catch ex {
            Set caught = 1
        }
        Do $$$AssertEquals(caught, 1, "a Python ValueError can be handled with Try/Catch")
    }
}
