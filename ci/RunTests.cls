Class PatientRegistry.CI.RunTests
{

ClassMethod Run() As %Status
{
    #include %occStatus
    Try {
        Set $Namespace = "%SYS"
        Set directory = "/usr/irissys/mgr/registrytest/"
        If '##class(%File).CreateDirectoryChain(directory) {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Cannot create test database directory"))
        }
        Set database = ##class(SYS.Database).%New()
        Set database.Directory = directory
        Set sc = database.%Save()
        $$$ThrowOnError(sc)
        Set properties("Directory") = directory
        Set sc = ##class(Config.Databases).Create("REGISTRYTEST", .properties)
        $$$ThrowOnError(sc)
        Kill properties
        Set properties("Globals") = "REGISTRYTEST", properties("Routines") = "REGISTRYTEST"
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
