# TODO: Review this soon, as it seems to be relying on other behaviour...
Describe "New-EnvConfig" {

    BeforeAll {

        # Import function under test
        . $PSScriptRoot/New-EnvConfig.ps1

        # Import dependent functions
        . $PSScriptRoot/../command/Stop-Task.ps1
        . $PSScriptRoot/../utils/Confirm-Parameters.ps1
        . $PSScriptRoot/../utils/Get-EnvConfig.ps1

        # Import dependent classes
        . $PSScriptRoot/../classes/StopTaskException.ps1

        # Create the testFolder
        $testFolder = (New-Item 'TestDrive:\folder' -ItemType Directory).FullName

        # Create file to be used for testing
        $stageVarFile = [IO.Path]::Combine($testFolder, "stagevars.yml")
        Set-Content -Path $stageVarFile -Value @"
default:
    variables:
    credentials:
        azure:
            - name: ARM_CLIENT_ID

stages:
    - name: pester
      variables:
        - name: PESTER_TEST_VAR
          description: Test variable for Pester unit tests
        - name: TF_region
          cloud: [aws]
"@

        # Mocks
        Mock -Command Write-Warning -MockWith {}
        Mock -Command Write-Error -MockWith {}

    }

    Context "Check parameters" {

        It "will error if path and scriptPath have not been specified" {
            New-EnvConfig

            Should -InvokeVerifiable
            Should -Invoke -CommandName Write-Error -Times 1
        }

        It "will error if the path to the config file is not specified" {

            { New-EnvConfig -Path $testfolder/pester.yaml -ScriptPath $testfolder }
                | Should -Throw "Specified file does not exist: $testfolder/pester.yaml`nTask failed due to errors detailed above"

            Should -Invoke -CommandName Write-Error -Times 1
        }
    }

    Context "Create script" {

        It "will create a PowerShell script with vars - Azure" {

            New-EnvConfig -Path $stageVarFile -ScriptPath $testfolder -Cloud Azure -Stage pester

            $scriptPath = [IO.Path]::Combine($testFolder, "envvar-azure-pester.ps1")

            # Check that the script has been created
            Test-Path -Path $scriptPath | Should -BeTrue

            # Ensure the script has the correct format
            $script = Get-Content -Path $scriptPath
            $script | Select-String -Pattern '\$env\:[A-Z_]*=\".*\"$' | Should -BeTrue
            $script | Select-String -Pattern "^#\s+Test variable for pester unit tests"
        }

        It "will create a bash compatible script - Azure" {

            $env:SHELL = "bash"

            New-EnvConfig -Path $stageVarFile -ScriptPath $testfolder -Cloud Azure -Stage pester

            $scriptPath = [IO.Path]::Combine($testFolder, "envvar-azure-pester.sh")

            # Check that the script has been created
            Test-Path -Path $scriptPath | Should -BeTrue

            # Ensure the script has the correct format
            $script = Get-Content -Path $scriptPath
            $script | Select-String -Pattern 'export [A-Z_]*=\".*\"$' | Should -BeTrue
            $script | Select-String -Pattern "^#\s+Test variable for pester unit tests"

            Remove-Item -Path env:\SHELL
        }

        It "will create a PowerShell script with vars - AWS" {

            New-EnvConfig -Path $stageVarFile -ScriptPath $testfolder -Cloud AWS -Stage pester

            $scriptPath = [IO.Path]::Combine($testFolder, "envvar-azure-pester.ps1")

            # Check that the script has been created
            Test-Path -Path $scriptPath | Should -BeTrue

            # Ensure the script has the correct format
            $script = Get-Content -Path $scriptPath
            $script | Select-String -Pattern '\$env\:[A-Z_]*=\".*\"$' | Should -BeTrue
        }

        It "will create a bash compatible script - AWS" {

            $env:SHELL = "bash"

            New-EnvConfig -Path $stageVarFile -ScriptPath $testfolder -Cloud AWS -Stage pester

            $scriptPath = [IO.Path]::Combine($testFolder, "envvar-azure-pester.sh")

            # Check that the script has been created
            Test-Path -Path $scriptPath | Should -BeTrue

            # Ensure the script has the correct format
            $script = Get-Content -Path $scriptPath
            $script | Select-String -Pattern 'export [A-Z_]*=\".*\"$' | Should -BeTrue

            Remove-Item -Path env:\SHELL
        }
    }


}
