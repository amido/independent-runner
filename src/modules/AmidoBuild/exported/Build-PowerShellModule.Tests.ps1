
Describe "Build-PowerShellModule" {

    BeforeAll {

        # Import the function under test
        . $PSScriptRoot/Build-PowerShellModule.ps1

        # Import dependent functions
        . $PSScriptRoot/../utils/Confirm-Parameters.ps1
        . $PSScriptRoot/../utils/Convert-HashToString.ps1
        . $PSScriptRoot/../utils/Convert-ArrayToString.ps1
        . $PSScriptRoot/../utils/Protect-Filesystem.ps1

        # Create test folder to work with
        $testFolder = (New-Item 'TestDrive:\folder' -ItemType Directory).FullName

        # Mock functions
        Mock -CommandName Write-Error -MockWith { } -ParameterFilter { $Message.ToLower().Contains("required parameters are missing") }
        Mock -CommandName Write-Error -MockWith { } -ParameterFilter { $Message.ToLower().Contains("specified module path does not exist") }
        Mock -CommandName Write-Error -MockWith { } -ParameterFilter { $Message.ToLower().Contains("module data file cannot be found") }

        Mock -CommandName Write-Warning -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
    }

    Context "Errors will be generated" {

        It "if no parameters are set" {

            $result = Build-PowerShellModule

            $result | Should -Be $false
            Should -Invoke -CommandName Write-Error -Times 1
        }

        It "if the module path does not exist" {
            $result = Build-PowerShellModule -Path "nonexistentpath" -Name MyModule

            $result | Should -Be $false
            Should -Invoke -CommandName Write-Error -Times 1
        }

        It "if the output directory does not exist and is not in the current directory" {

            $result = Build-PowerShellModule -Path $testFolder -Name MyModule -Output "../../outputs"

            $result | Should -Be $false
        }

        It "the PowerShell data file cannot be located in a valid path" {

            # Make an output directory
            $outputDir = New-Item -ItemType Directory -Path ([IO.Path]::Combine($testFolder, "outputs"))

            $result = Build-PowerShellModule -Path $testFolder -Name MyModule -Target $outputDir.FullName

            $result | Should -Be $false
            Should -Invoke -CommandName Write-Error -Times 1

            Remove-Item -Path $outputDir.FullName -Force
        }
    }

    Context "Warnings will be generated" {

        BeforeAll {
            $testFolder2 = (New-Item 'TestDrive:\folder2' -ItemType Directory).FullName
            $modulesDir2 = New-Item -ItemType Directory -Path ([IO.Path]::Combine($testFolder, "src", "modules"))
        }

        AfterEach {
            Remove-Item -Path $testFolder2 -Recurse -Force
        }

        It "if the output path is a child of the current directory" {

            Push-Location -Path $testFolder2

            Build-PowerShellModule -Path $modulesDir2 -Name MyModule -Output "test_outputs"

            Test-Path -Path test_outputs | Should -Be $true

            Pop-Location
        }
    }

    Context "Build module" {

        BeforeEach {

            $outputDir = New-Item -ItemType Directory -Path ([IO.Path]::Combine($testFolder, "outputs"))

            Push-Location -path $outputDir

            # Create files in the src directory to mimic the module files
            $name = "MyModule"
            $modulesDir = New-Item -ItemType Directory -Path ([IO.Path]::Combine($testFolder, "src", "modules"))
            $moduleDir = New-Item -ItemType Directory -Path ([IO.Path]::Combine($modulesDir, $name))
            $functionsDir = New-Item -ItemType Directory -Path ([IO.Path]::Combine($moduleDir, "functions"))

            # Create the data file to be used
            $dataFile = New-Item -ItemType File -Path ([IO.Path]::Combine($moduleDir, ("{0}.psd1" -f $name))) -Value @"
@{
    RootModule = 'MyModule'
    ModuleVersion = '0.1'
    GUID = '4d21ec3e-55d1-4530-8a96-c1d339ea35d8'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        "Get-Test"
    )
}
"@

            # Create a function file to ensure that it gets into the PSM file
            Add-Content -Path ([IO.Path]::Combine($functionsDir, "Get-Test.ps1")) -Value @"
function Get-Test() {
    Write-Output "Running Pester Tests"
}
"@

            # Create a test file to ensure that it is not included
            Add-Content -Path ([IO.Path]::Combine($functionsDir, "Get-Test.Tests.ps1")) -Value @"
Describe "Get-Test" {

}
"@

        }

        AfterEach {
            Pop-Location
            Remove-Item -Path $testFolder -Force -Recurse
        }

        It "will create the PSM file with all the functions within" {

            # Build the module with all the functions
            Build-PowerShellModule -Path $modulesDir -Name MyModule -Target $outputDir.FullName

            # Check that the necessary files exist
            Test-Path -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psd1" -f $name))) | Should -Be $true
            Test-Path -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psm1" -f $name))) | Should -Be $true

            # The PSM file contains the functions in the files
            Get-Content -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psm1" -f $name))) -Raw | Should -BeLike "*function Get-Test()*"

            # It does not contain the test files
            Get-Content -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psm1" -f $name))) -Raw | Should -Not -BeLike "*Describe `"Get-Test`""
        }

        It "will create the module with a valid session object" {

            # Build the module with all the functions and a session object
            Build-PowerShellModule -Path $modulesDir -Name MyModule -Target $outputDir.FullName -SessionName "MyModuleSession" -SessionObject @{"commands" = @{"list" = @(); file = ""}}

            # Check that the necessary files exist
            Test-Path -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psd1" -f $name))) | Should -Be $true
            Test-Path -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psm1" -f $name))) | Should -Be $true

            # The PSM file contains the functions in the files
            Get-Content -Path ([IO.Path]::Combine($outputDir.FullName, "MyModule", ("{0}.psm1" -f $name))) -Raw | Should -BeLike '*$MyModuleSession = @{*commands*'

        }
    }
}
