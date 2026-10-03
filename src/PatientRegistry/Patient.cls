Class PatientRegistry.Patient Extends %Persistent
{

Property AssigningAuthority As %String(MAXLEN = 100, COLLATION = "EXACT") [ Required ];

Property MRN As %String(MAXLEN = 64, COLLATION = "EXACT") [ Required ];

Property GivenName As %String(MAXLEN = 100);

Property FamilyName As %String(MAXLEN = 100);

Property Address As PatientRegistry.Address;

Index Identity On (AssigningAuthority, MRN) [ Unique ];

ClassMethod FindByIdentity(authority As %String, mrn As %String, Output id As %String) As %Status
{
    #include %occStatus
    Set id = ""
    &sql(SELECT ID INTO :id
         FROM PatientRegistry.Patient
         WHERE AssigningAuthority = :authority AND MRN = :mrn)
    If (SQLCODE'=0)&&(SQLCODE'=100) Quit $$$ERROR($$$GeneralError, "Patient lookup failed: "_SQLCODE)
    Quit $$$OK
}

ClassMethod FromJSON(data As %DynamicObject, Output patient As PatientRegistry.Patient) As %Status
{
    Set patient = ..%New()
    Quit patient.MergeJSON(data)
}

Method MergeJSON(data As %DynamicObject) As %Status
{
    #include %occStatus
    If '$IsObject(data) Quit $$$ERROR($$$GeneralError, "Patient must be a JSON object")
    If 'data.%IsA("%DynamicObject") Quit $$$ERROR($$$GeneralError, "Patient must be a JSON object")
    If data.%GetTypeOf("assigningAuthority")'="string" Quit $$$ERROR($$$GeneralError, "Assigning authority is required")
    If data.%Get("assigningAuthority")="" Quit $$$ERROR($$$GeneralError, "Assigning authority is required")
    If data.%GetTypeOf("mrn")'="string" Quit $$$ERROR($$$GeneralError, "MRN is required")
    If data.%Get("mrn")="" Quit $$$ERROR($$$GeneralError, "MRN is required")
    If (..AssigningAuthority'="")&&(..AssigningAuthority'=data.%Get("assigningAuthority")) {
        Quit $$$ERROR($$$GeneralError, "Assigning authority cannot change")
    }
    If (..MRN'="")&&(..MRN'=data.%Get("mrn")) Quit $$$ERROR($$$GeneralError, "MRN cannot change")
    Set sc = $$$OK
    For key = "givenName", "familyName" {
        If data.%IsDefined(key), data.%GetTypeOf(key)'="string" {
            Set sc = $$$ERROR($$$GeneralError, "Names must be strings")
            Quit
        }
    }
    If $$$ISERR(sc) Quit sc
    Set ..AssigningAuthority = data.%Get("assigningAuthority"), ..MRN = data.%Get("mrn")
    If data.%IsDefined("givenName") Set ..GivenName = data.%Get("givenName")
    If data.%IsDefined("familyName") Set ..FamilyName = data.%Get("familyName")
    If data.%IsDefined("address") {
        If data.%GetTypeOf("address")="null" {
            Set ..Address = ""
        } Else {
            If '$IsObject(..Address) Set ..Address = ##class(PatientRegistry.Address).%New()
            Set sc = ..Address.MergeJSON(data.%Get("address"))
            If $$$ISERR(sc) Quit sc
        }
    }
    Quit $$$OK
}

Method ToJSON() As %DynamicObject
{
    Set data = {}
    Do data.%Set("assigningAuthority", ..AssigningAuthority)
    Do data.%Set("mrn", ..MRN)
    Do data.%Set("givenName", ..GivenName)
    Do data.%Set("familyName", ..FamilyName)
    If '..Address.%IsNull() {
        Do data.%Set("address", ..Address.ToJSON())
    } Else {
        Do data.%Set("address", "", "null")
    }
    Quit data
}

ClassMethod MergeSafeUpdate(data As %DynamicObject, Output id As %String, timeout As %Integer = 5) As %Status
{
    #include %occStatus
    Set id = ""
    If $TLevel Quit $$$ERROR($$$GeneralError, "MergeSafeUpdate requires no active transaction")
    If timeout<0 Quit $$$ERROR($$$GeneralError, "Lock timeout cannot be negative")
    Set sc = ..FromJSON(data, .candidate)
    If $$$ISERR(sc) Quit sc
    Set sc = candidate.%ValidateObject()
    If $$$ISERR(sc) Quit sc
    Set authority = candidate.AssigningAuthority, mrn = candidate.MRN
    Lock +^PatientRegistry.Lock(authority, mrn):timeout
    If '$Test Quit $$$ERROR($$$GeneralError, "Patient update lock timed out")
    Set level = $TLevel, sc = $$$OK
    Try {
        TStart
        Set sc = ..FindByIdentity(authority, mrn, .existingID)
        $$$ThrowOnError(sc)
        If existingID="" {
            Set patient = candidate
        } Else {
            Set patient = ..%OpenId(existingID, 0, .sc)
            $$$ThrowOnError(sc)
            If '$IsObject(patient) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Patient no longer exists"))
            Set sc = patient.%Reload()
            $$$ThrowOnError(sc)
            Set sc = patient.MergeJSON(data)
            $$$ThrowOnError(sc)
        }
        Set sc = patient.%ValidateObject()
        $$$ThrowOnError(sc)
        Set sc = patient.%Save()
        $$$ThrowOnError(sc)
        Set id = patient.%Id()
        TCommit
    } Catch exception {
        If $TLevel>level TRollback 1
        Set sc = exception.AsStatus(), id = ""
    }
    Lock -^PatientRegistry.Lock(authority, mrn)
    Quit sc
}

ClassMethod CheckDigit(payload As %String) As %String [ Language = python ]
{
    if not payload or not payload.isascii() or not payload.isdigit():
        raise ValueError("MRN payload must contain only ASCII digits")
    total = 0
    for index, character in enumerate(reversed(payload)):
        digit = int(character)
        if index % 2 == 0:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return str((-total) % 10)
}

}
