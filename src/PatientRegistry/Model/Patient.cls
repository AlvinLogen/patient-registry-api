Class PatientRegistry.Model.Patient Extends %Persistent
{
    Parameter SCHEMAVERSION = "1.0.0";
    Parameter DEFAULTGLOBAL = "^PatReg.Patient";

    Property AssigningAuthority As %String(MAXLEN = 30, MINLEN = 2) [Required];
    Property MRN As %String(MAXLEN = 20, PATTERN = "1.20AN") [Required];
    Property FamilyName As %String(MAXLEN = 80) [Required];
    Property GivenName As %String(MAXLEN = 80) [Required];
    Property BirthDate As %Date;
    Property AdministrativeSex As %String(VALUELIST = ",F,M,O,U");
    Property HomeAddress As PatientRegistry.Model.Address;
    Property Active As %Boolean [InitialExpression = 1];
    Property Version As %Integer [InitialExpression = 1];
    Property CreatedAt As %TimeStamp;
    Property UpdatedAt as %TimeStamp;

    Index IdentifierIdx ON (AssigningAuthority, MRN) [Unique];
    Index FamilyNameIdx ON FamilyName;

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
    Method %OnBeforeSave(insert As %Boolean) As %Status [Private, ServerOnly = 1]
    {
        Set now = $ZDATETIME($ZTIMESTAMP, 3, 1, 3)
        if insert { Set ..CreatedAt = now}
        Set ..UpdatedAt = now
        Quit $$$OK
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
