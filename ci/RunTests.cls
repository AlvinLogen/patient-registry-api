Class PatientRegistry.CI.RunTests
{

ClassMethod Run() As %Status
{
    #include %occStatus
    Try {
        Set $Namespace = "%SYS"
        Set properties("Globals") = "USER", properties("Routines") = "USER"
        Set sc = ##class(Config.Namespaces).Create("REGISTRYTEST", .properties)
        $$$ThrowOnError(sc)
        Set $Namespace = "REGISTRYTEST"
        Set sc = $System.OBJ.LoadDir("/opt/patient-registry/src", "ck", , 1)
        $$$ThrowOnError(sc)
        Set sc = $System.OBJ.LoadDir("/opt/patient-registry/tests/iris", "ck", , 1)
        $$$ThrowOnError(sc)
        Set ^UnitTestRoot = "/opt/patient-registry/tests"
        Set sc = ##class(%UnitTest.Manager).RunTest("iris", "/nodelete/noload")
        $$$ThrowOnError(sc)
        If '$ListGet($Get(^UnitTest.Result($Get(^UnitTest.Result), "iris")), 1) {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "IRIS unit tests failed"))
        }
        Set sc = $$$OK
    } Catch exception {
        Set sc = exception.AsStatus()
    }
    Quit sc
}

}
