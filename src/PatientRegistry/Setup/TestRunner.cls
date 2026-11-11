/// Runs the %UnitTest suite and reports a single yes/no. Used by developers and by CI.
Class PatientRegistry.Setup.TestRunner
{
    /// Root directory that contains the PatientRegistry/Tests suite folder.
    Parameter TESTROOT = "/home/irisowner/dev/src";

    /// Returns 1 when every test passed, otherwise 0.
    ClassMethod Run() As %Boolean
    {
        Set passed = 0
        Try {
            Set ^UnitTestRoot = ..#TESTROOT
            Do ##class(%UnitTest.Manager).RunTest("PatientRegistry/Tests", "/nodelete")
            Set instance = $ORDER(^UnitTest.Result(""), -1)
            If instance '= "" {
                Set stmt = ##class(%SQL.Statement).%New()
                // TestInstance has no Status; a run passes when it has suites and none failed.
                $$$ThrowOnError(stmt.%Prepare("SELECT COUNT(*) AS Total, SUM(CASE WHEN Status = 1 THEN 0 ELSE 1 END) AS Failed FROM %UnitTest_Result.TestSuite WHERE TestInstance = ?"))
                Set rs = stmt.%Execute(instance)
                If rs.%Next() {
                    Set passed = ((rs.%Get("Total") > 0) && (+rs.%Get("Failed") = 0))
                }
            }
        } Catch ex {
            Write ex.DisplayString(), !
        }
        Quit passed
    }

}
