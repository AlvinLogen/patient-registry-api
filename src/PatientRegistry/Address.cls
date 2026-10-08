Class PatientRegistry.Address Extends %SerialObject
{

Property Line1 As %String(MAXLEN = 200);

Property City As %String(MAXLEN = 100);

Property PostalCode As %String(MAXLEN = 20);

Property Country As %String(MAXLEN = 2);

Method MergeJSON(data As %DynamicObject) As %Status
{
    #include %occStatus
    If '$IsObject(data) Quit $$$ERROR($$$GeneralError, "Address must be a JSON object")
    If 'data.%IsA("%DynamicObject") Quit $$$ERROR($$$GeneralError, "Address must be a JSON object")
    Set fields = "line1,city,postalCode,country"
    Set sc = $$$OK
    For i = 1:1:4 {
        Set key = $Piece(fields, ",", i)
        If data.%IsDefined(key), data.%GetTypeOf(key)'="string" {
            Set sc = $$$ERROR($$$GeneralError, "Address fields must be strings")
            Quit
        }
    }
    If $$$ISERR(sc) Quit sc
    If data.%IsDefined("line1") Set ..Line1 = data.%Get("line1")
    If data.%IsDefined("city") Set ..City = data.%Get("city")
    If data.%IsDefined("postalCode") Set ..PostalCode = data.%Get("postalCode")
    If data.%IsDefined("country") Set ..Country = data.%Get("country")
    Quit $$$OK
}

Method ToJSON() As %DynamicObject
{
    Set data = {}
    Do data.%Set("line1", ..Line1)
    Do data.%Set("city", ..City)
    Do data.%Set("postalCode", ..PostalCode)
    Do data.%Set("country", ..Country)
    Quit data
}

}
