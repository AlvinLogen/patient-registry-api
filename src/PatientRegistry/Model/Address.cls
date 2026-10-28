/// Postal address embedded inside a Patient. Serial: stored inside the owner's data node, no extent of its own.
Class PatientRegistry.Model.Address Extends %SerialObject {
    Property Line1 As %String (MAXLEN = 100);
    Property Line2 As %String (MAXLEN = 100);
    Property City As %String (MAXLEN = 60);
    Property Region As %String (MAXLEN = 60);
    Property PostalCode As %String (MAXLEN = 12);

    /// ISO 3166-1 alpha-2 country code.
    Property Country As %String (MAXLEN = 2, MINLEN = 2) [InitialExpression = "ZA"];

    /// Canonical JSON form. Every field is typed as a string so values such as "1000" stay strings.
    Method ToDynamicObject() As %DynamicObject
    {
        Set obj = {}
        Do obj.%Set("line1", ..Line1, "string")
        Do obj.%Set("line2", ..Line2, "string")
        Do obj.%Set("city", ..City, "string")
        Do obj.%Set("region", ..Region, "string")
        Do obj.%Set("postalCode", ..PostalCode, "string")
        Do obj.%Set("country", ..Country, "string")
        Quit obj
    }

    /// Merge-patch: only the keys present in pChanges are applied.
    Method ApplyChanges(pChanges As %DynamicObject)
    {
        if pChanges.%IsDefined("line1") { Set ..Line1 = pChanges.line1}
        if pChanges.%IsDefined("line2") {Set ..Line2 = pChanges.line2}
        if pChanges.%IsDefined("city") { Set ..City = pChanges.city}
        if pChanges.%IsDefined("region") { Set ..Region = pChanges.region}
        if pChanges.%IsDefined("postalCode") { Set ..PostalCode = pChanges.postalCode}
        if pChanges.%IsDefined("country") { Set ..Country = pChanges.country}
    }

    ClassMethod FromDynamicObject(pObj As %DynamicObject) As PatientRegistry.Model.Address
    {
        Set address = ..%New()
        Do address.ApplyChanges(pObj)
        Quit address
    }
}
