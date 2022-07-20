Describe "Get-EnvConfig" {

    $ModulePath

    BeforeAll {

        # Import classes needed
        . $PSScriptRoot/../classes/StopTaskException.ps1

        # Import function under test
        . $PSScriptRoot/Get-EnvConfig.ps1

        # Import dependent functions
        . $PSScriptRoot/../command/Stop-Task.ps1
        . $PSScriptRoot/Confirm-Parameters.ps1
        . $PSScriptRoot/Get-EnvConfig.ps1

        # Make stubbed module available
        $ModulePath = $env:PSModulePath
        $env:PSModulePath = "$PSScriptRoot/../../../../test/stubs/modules$([IO.Path]::PathSeparator)$env:PSModulePath"

        $stageVars = @{
            default = @{
                variables = $null
                credentials = @{
                    azure = @(
                        @{
                            name = "ARM_CLIENT_ID"
                        }
                    )
                }
            }
            stages = @(
                @{
                    name = "pester"
                    variables = @(
                        @{
                            name = "PESTER_TEST_VAR"
                            description = "Test variable for Pester unit tests"
                        },
                        @{
                            name = "TF_region"
                            cloud = @(
                                "aws"
                            )
                        }
                    )
                }
            )
        }

        # Mocks
        Mock -Command Write-Host -MockWith { }
        Mock -Command Write-Warning -MockWith { }
        Mock -Command Write-Error -MockWith { }
        Mock -Command Get-Content -MockWith { }
        Mock -Command Test-Path -MockWith { return $true }
        function ConvertFrom-Yaml {}
        Mock -Command ConvertFrom-Yaml -MockWith { return $stageVars }
    }

    AfterAll {
        $env:PSModulePath = $ModulePath
    }

    It "will produce a warning if the stage is not specified" {

        $result = Get-EnvConfig -Path 'noop' -Cloud Azure

        $result.count | Should -Be 1
        Should -Invoke Write-Warning -Times 1
    }

    It "will return 2 items for Azure" {

        $result = Get-EnvConfig -Path 'noop' -Cloud Azure -Stage pester

        $result.count | Should -Be 2
    }

    It "will return 2 items for AWS" {
        $result = Get-EnvConfig -Path 'noop' -Cloud AWS -Stage pester

        $result.count | Should -Be 2
    }

}
