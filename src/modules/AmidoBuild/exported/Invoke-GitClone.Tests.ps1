
Describe "Invoke-GitClone" {

    BeforeAll {

        # Import the function being tested
        . $PSScriptRoot/Invoke-GitClone.ps1

        # Import depdencies
        . $PSScriptRoot/../utils/Confirm-IsWebAddress.ps1

        # Create the testFolder
        $testFolder = (New-Item 'TestDrive:\folder' -ItemType Directory).FullName

        # Mock functions that are called
        # - Write-Error - mock this internal function to check that errors are being raised
        Mock -Command Write-Error -MockWith { return $MessageData } -Verifiable

        # - Invoke-WebRequest - do not want to actually perform a clone at this point
        Mock -Command Invoke-WebRequest -MockWith {}

        # - Expand-Archive - check that the zip file is being unpacked
        Mock -Command Expand-Archive -MockWith {}

        # - Move-Item - this is used to move the unpacked directory to one that matches the
        #               repository name
        Mock -Command Move-Item -MockWith {}

        # - Remove-Item
        Mock -Command Remove-Item -MockWith {}
    }

    Context "Use an unsupported remote source control" {

        It "will error" {

            Invoke-GitClone -Type pestergit -Repo "amido/stacks-dotnet"

            Should -Invoke -CommandName Write-Error -Times 1
        }
    }

    Context "Cloning from GitHub" {

        It "will error if no repo is set" {
            Invoke-GitClone -Type github

            Should -Invoke -CommandName Write-Error -Times 1
        }

        It "will generate a valid GitHub URL if shorthand repo is specified" {
            $result = $(Invoke-GitClone -Type github -Repo "amido/stacks-dotnet" -Verbose) 4>&1

            $result[0] | Should -Be "https://github.com/amido/stacks-dotnet/archive/main.zip"
        }

        It "will not modify a repo that is a URL" {
            $url = "https://github.com/amido/stacks-cli/archive/main.zip"

            $result = $(Invoke-GitClone -Type github -Repo $url -Verbose) 4>&1

            $result[0] | Should -Be $url

            # Invoke-WebRequest should have been called
            Should -Invoke -CommandName Invoke-WebRequest -Times 1
        }
    }

    Context "unpacking cloned file" {

        BeforeAll {

            # Create a dummy zip file in the testfolder to work with
            New-Item -ItemType File -Path (Join-Path -Path $testFolder -ChildPath "amido_stacks-cli_main.zip")
        }

        It "will attempt to unpack the downloaded zip file" {

            $result = $(Invoke-GitClone -Type github -Repo "amido/stacks-cli" -Path $testFolder -Verbose) 4>&1

            $result[1] | Should -Be ([IO.Path]::Combine($testFolder, "amido_stacks-cli_main.zip"))

            Should -Invoke -CommandName Expand-Archive -Times 1
            Should -Invoke -CommandName Move-Item -Times 1
            Should -Invoke -CommandName Remove-Item -Times 1
        }
    }
}
