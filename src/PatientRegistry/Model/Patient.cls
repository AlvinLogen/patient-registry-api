Class PatientRegistry.Model.Patient Extends %Persistent
{

Parameter SCHEMAVERSION = "1.1.0";

Parameter DEFAULTGLOBAL = "^PatReg.Patient";

Property AssigningAuthority As %String(MAXLEN = 30, MINLEN = 2) [ Required ];

Property MRN As %String(MAXLEN = 20, PATTERN = "1.20AN") [ Required ];

Property FamilyName As %String(MAXLEN = 80) [ Required ];

Property GivenName As %String(MAXLEN = 80) [ Required ];

Property BirthDate As %Date;

/// HL7 administrative sex: F, M, O (other), U (unknown).
Property AdministrativeSex As %String(VALUELIST = ",F,M,O,U");

Property HomeAddress As PatientRegistry.Model.Address;

Property Active As %Boolean [ InitialExpression = 1 ];

Property Version As %Integer [ InitialExpression = 1 ];

Property CreatedAt As %TimeStamp;

Property UpdatedAt As %TimeStamp;

Index IdentifierIdx On (AssigningAuthority, MRN) [ Unique ];

Index FamilyNameIdx On FamilyName;

/// Returns the patient with this identity, or "" when there is none.
ClassMethod FindByIdentifier(pAuthority As %String, pMRN As %String) As PatientRegistry.Model.Patient
{
        Quit ..IdentifierIdxOpen(pAuthority, pMRN)
}

Method FullName() As %String
{
        Quit ..GivenName_" "_..FamilyName
}

/// Sets audit timestamp in UTC just before every save.
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
        Set now = $ZDATETIME($ZTIMESTAMP, 3, 1, 3)
        if insert { Set ..CreatedAt = now}
        Set ..UpdatedAt = now
        Quit $$$OK
}

/// A register never forgets a patient: use PatientService.Deactivate instead.
ClassMethod %OnDelete(oid As %ObjectIdentity) As %Status [ Private, ServerOnly = 1 ]
{
        Quit $$$ERROR($$$GeneralError, "PR-HARD-DELETE-FORBIDDEN: deactivate the patient instead")
}

/// Canonical JSON form (docs/canonical-patient-mapping.md). Identify and text fields are typed as strings.
Method ToDynamicObject() As %DynamicObject
{
        Set obj = {}
        Do obj.%Set("assigningAuthority", ..AssigningAuthority, "string")
        Do obj.%Set("mrn", ..MRN, "string")
        Do obj.%Set("familyName", ..FamilyName, "string")
        Do obj.%Set("givenName", ..GivenName, "string")
        
        if ..BirthDate '= "" {
            Do obj.%Set("birthDate", $ZDATE(..BirthDate, 3), "string")
        } Else {
            Do obj.%Set("birthDate", "", "null")
        }

        Do obj.%Set("administrativeSex", ..AdministrativeSex, "string")

        if $ISOBJECT(..HomeAddress) {
            Do obj.%Set("homeAddress", ..HomeAddress.ToDynamicObject())
        } Else {
            Do obj.%Set("homeAddress", "", "null")
        }

        Do obj.%Set("active", +..Active, "boolean")
        Do obj.%Set("version", ..Version, "number")
        Do obj.%Set("createdAt", ..IsoUtc(..CreatedAt), "string")
        Do obj.%Set("updatedAt", ..IsoUtc(..UpdatedAt), "string")
        Quit obj
}

/// Merge-Patch: applies only the EDITABLE fields present in pChanges. Identity, version and audit fields are never read from input.
Method ApplyChanges(pChanges As %DynamicObject) As %Status
{
        Set sc = $$$OK
        Try {
            If pChanges.%IsDefined("familyName") { Set ..FamilyName = pChanges.familyName}
            If pChanges.%IsDefined("givenName") { Set ..GivenName = pChanges.givenName}
            If pChanges.%IsDefined("administrativeSex") { Set ..AdministrativeSex = pChanges.administrativeSex}
            If pChanges.%IsDefined("active") { Set ..Active = pChanges.active}
            If pChanges.%IsDefined("birthDate") {
                Set text = pChanges.birthDate
                If text = "" {
                    Set ..BirthDate = ""
                } ElseIf text '? 4N1"-"2N1"-"2N {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, "birthDate must be YYYY-MM-DD"))
                } Else {
                    Set ..BirthDate = $ZDATEH(text, 3)
                }
            }

            If $ISOBJECT(pChanges.homeAddress){
                if '$ISOBJECT(..HomeAddress){
                    Set ..HomeAddress = ##class(PatientRegistry.Model.Address).%New()
                }

                Do ..HomeAddress.ApplyChanges(pChanges.homeAddress)
            }
        } Catch ex {
            Set sc = ex.AsStatus()
        }

        Quit sc
}

/// Builds an UNSAVED patient from canonical JSON. Identify fields must be JSON strings.
ClassMethod FromDynamicObject(pObj As %DynamicObject, Output pPatient As PatientRegistry.Model.Patient) As %Status
{
        Set sc = $$$OK
        Set pPatient = ""
        Try {
            if ('$ISOBJECT(pObj)) || ($CLASSNAME(pObj) '= "%Library.DynamicObject") {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "patient must be a JSON object"))
            }

            For key = "assigningAuthority", "mrn", "familyName", "givenName" {
                If pObj.%GetTypeOf(key) '= "string" {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, "field " _key_" must be a string"))
                }
            }

            Set patient = ..%New()
            Set patient.AssigningAuthority = pObj.assigningAuthority
            Set patient.MRN = pObj.mrn
            $$$ThrowOnError(patient.ApplyChanges(pObj))
            Set pPatient = patient

        } Catch ex {
            Set sc = ex.AsStatus()
        }
        Quit sc
}

/// Number of ACTIVE patients with this family name (case-insensitive, via the column collation).
ClassMethod CountByFamilyName(pFamilyName As %String, Output pCount As %Integer) As %Status
{
        Set pCount = 0
        &sql(SELECT COUNT(*) INTO :pCount
            FROM PatientRegistry_Model.Patient
            WHERE Active = 1 AND FamilyName = :pFamilyName)
        IF SQLCODE < 0 {
            Quit ##class(%SYSTEM.Error).FromSQLCode(SQLCODE, %msg)
        }

        Quit $$$OK
}

/// ACTIVE patients with this family name, as a JSON array of canonical objects ordered by ID.
ClassMethod FindByFamilyName(pFamilyName As %String, Output pResult As %DynamicObject) As %Status
{
        Set sc = $$$OK
        Set pResult = []
        Try {
            &sql(DECLARE FamilyCursor CURSOR FOR 
                SELECT ID INTO :id
                FROM PatientRegistry_Model.Patient
                WHERE Active = 1 AND FamilyName = :pFamilyName
                ORDER BY ID)
            &sql(OPEN FamilyCursor)
            If SQLCODE < 0 {
                $$$ThrowStatus(##class(%SYSTEM.Error).FromSQLCode(SQLCODE, %msg))
            }
            
            For {
                &sql(FETCH FamilyCursor)
                Quit:SQLCODE'=0
                Set patient = ..%OpenId(id)
                If $ISOBJECT(patient){
                    Do pResult.%Push(patient.ToDynamicObject())
                }
            }

            Set fetchCode = SQLCODE
            &sql(CLOSE FamilyCursor)
            If fetchCode < 0 {
                $$$ThrowStatus(##class(%SYSTEM.Error).FromSQLCode(fetchCode, %msg))
            }

        } Catch ex {
            Set sc = ex.AsStatus()
        }
        Quit sc
}

/// "2026-10-01 12:34:56.789" -> "2026-10-01T12:34:56.789Z" (ISO 8601 UTC); "" stays "".
ClassMethod IsoUtc(pTimeStamp As %String) As %String [ Private ]
{
        If pTimeStamp = "" {
            Quit ""
        }

        Quit $TRANSLATE(pTimeStamp, " ", "T")_"Z"
}

Storage Default
{
<Data name="PatientDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>AssigningAuthority</Value>
</Value>
<Value name="3">
<Value>MRN</Value>
</Value>
<Value name="4">
<Value>FamilyName</Value>
</Value>
<Value name="5">
<Value>GivenName</Value>
</Value>
<Value name="6">
<Value>BirthDate</Value>
</Value>
<Value name="7">
<Value>AdministrativeSex</Value>
</Value>
<Value name="8">
<Value>HomeAddress</Value>
</Value>
<Value name="9">
<Value>Active</Value>
</Value>
<Value name="10">
<Value>Version</Value>
</Value>
<Value name="11">
<Value>CreatedAt</Value>
</Value>
<Value name="12">
<Value>UpdatedAt</Value>
</Value>
</Data>
<DataLocation>^PatReg.PatientD</DataLocation>
<DefaultData>PatientDefaultData</DefaultData>
<IdLocation>^PatReg.PatientD</IdLocation>
<IndexLocation>^PatReg.PatientI</IndexLocation>
<StreamLocation>^PatReg.PatientS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
