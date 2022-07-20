# TODO: Are these tests actually testing Confirm-Environment, it appears to be more of a Get-EnvConfig test file..?
Describe "Confirm-Environment" {

    BeforeAll {

        # Import function under test
        . $PSScriptRoot/Confirm-Environment.ps1

        # Import dependent functions
        . $PSScriptRoot/../command/Stop-Task.ps1
        . $PSScriptRoot/../utils/Confirm-Parameters.ps1
        . $PSScriptRoot/../utils/Get-EnvConfig.ps1

        # Import dependent classes
        . $PSScriptRoot/../classes/StopTaskException.ps1

        # Mocks
        Mock -Command Write-Error -MockWith { }
        Mock -Command Write-Warning -MockWith { }
    }

    Context "Check parameters" {
        It "will error if no path is provided" {
            Mock `
                -Command Stop-Task `
                -Verifiable `
                -MockWith {
                    throw [StopTaskException]::new(1, "TestExceptionThrown")
                } `
                -ParameterFilter { $Message -eq "Specified file does not exist: " }

            $ShouldParams = @{
                Throw = $true
                ExceptionType = [StopTaskException]
                ExpectedMessage = "TestExceptionThrown"
                # Command to run
                ActualValue = { Confirm-Environment }
            }

            Should @ShouldParams
            Should -InvokeVerifiable
        }
    }

    Context "Enviroment" {

        It "will error and terminate because PESTER_TEST_VAR is not set" {
            Mock -Command Get-EnvConfig -MockWith {
                @{
                    name = "PESTER_TEST_VAR"
                }
            }

            Mock `
                -Command Stop-Task `
                -Verifiable `
                -MockWith {
                    throw [StopTaskException]::new(1, "TestExceptionThrown")
                } `
                -ParameterFilter {
                    $Message -eq "The following environment variables are missing and must be provided:" `
                        + "`n`tPESTER_TEST_VAR" `
                }

            $ShouldParams = @{
                Throw = $true
                ExceptionType = [StopTaskException]
                ExpectedMessage = "TestExceptionThrown"
                # Command to run
                ActualValue = { Confirm-Environment -Path $stageVarFile -Stage "pester" }
            }

            Should @ShouldParams

            Should -InvokeVerifiable
        }

        # Check that as there are no default variables the config file there will be
        # no error or exception
        It "will not throw if no stage has been specified" {
            Mock -Command Get-EnvConfig -MockWith { return @{} }

            {  Confirm-Environment -Path 'noop' } | Should -Not -Throw

            Should -Command Write-Error -Exactly 0
        }

        it "will ignore cloud specific vars if no cloud has been specified" {
            Mock -Command Get-EnvConfig -MockWith {
                @{
                    name = "PESTER_TEST_VAR"
                }
            }

            $results = Confirm-Environment -Path 'noop' -Passthru -stage pester

            $results.count | Should -Be 1
        }

        # Ensure that when a cloud has been specified the correct number of missing variables is set properly
        # This tests that cloud specified variables can be added to the configuration file and referenced properly
        it "will check cloud specific variables" {
            Mock -Command Get-EnvConfig -MockWith {
                return @(
                    @{
                        name = "PESTER_TEST_VAR"
                    }
                    @{
                        name = "TF_region"
                        cloud = @("aws")
                    }
                )
            }


            $results = Confirm-Environment -Path 'noop' -Cloud aws -Passthru -stage pester

            $results.count | Should -Be 2
        }
    }
}
