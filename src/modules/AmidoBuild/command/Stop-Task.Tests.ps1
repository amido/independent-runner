Describe "Stop-Task" {

    BeforeAll {
        # Import function under test
        . $PSScriptRoot/Stop-Task.ps1

        # Import dependent functions
        . $PSScriptRoot/../utils/Confirm-Parameters.ps1

        # Import dependent classes
        . $PSScriptRoot/../classes/StopTaskException.ps1

        # Mocks
        Mock -Command Write-Error -MockWith { }
    }

    It "will write out an error and produce an exception" {

        { Stop-Task -Message "Pester Test" } | Should -Throw "Pester Test`nTask failed due to errors detailed above"

        Should -Invoke -CommandName Write-Error -Times 1
    }

}
