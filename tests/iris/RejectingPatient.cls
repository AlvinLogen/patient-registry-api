Class PatientRegistry.Tests.RejectingPatient Extends PatientRegistry.Patient
{

Method %OnBeforeSave(insert As %Boolean) As %Status
{
    #include %occStatus
    If ..FamilyName="REJECT" Quit $$$ERROR($$$GeneralError, "Deliberate test save failure")
    Quit $$$OK
}

}
