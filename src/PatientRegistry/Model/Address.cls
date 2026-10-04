/// Postal address embeddd inside a Patient. Serial: stored inside the owner's data node, no extent of its own
Class PatientRegistry.Model.Address Extends %SerialObject
{
    Property Line1 As %String(MAXLEN = 100);
    Property Line2 AS %String(MAXLEN = 100);
    Property City AS %String(MAXLEN = 60);
    Property Region AS %String(MAXLEN = 60);
    Property PostalCode AS %String(MAXLEN = 12);
    Property Country AS %String(MAXLEN = 2, MINLEN = 2) [ InitialExpression = "ZA"];
Storage Default
{
<Data name="AddressState">
<Value name="1">
<Value>Line1</Value>
</Value>
<Value name="2">
<Value>Line2</Value>
</Value>
<Value name="3">
<Value>City</Value>
</Value>
<Value name="4">
<Value>Region</Value>
</Value>
<Value name="5">
<Value>PostalCode</Value>
</Value>
<Value name="6">
<Value>Country</Value>
</Value>
</Data>
<State>AddressState</State>
<StreamLocation>^PatientRegistry.Model.AddressS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
