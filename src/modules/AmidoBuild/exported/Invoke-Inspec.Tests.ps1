
Describe "Invoke-Inspec" {

    BeforeAll {

        # Import function under test
        . $PSScriptRoot/Invoke-Inspec.ps1

        # Import dependent functions
        . $PSScriptRoot/../command/Find-Command.ps1
        . $PSScriptRoot/../command/Invoke-External.ps1
        . $PSScriptRoot/../command/Stop-Task.ps1
        . $PSScriptRoot/../utils/Confirm-Parameters.ps1

        # Import dependent classes
        . $PSScriptRoot/../classes/StopTaskException.ps1

        # Create the testFolder
        $testFolder = (New-Item 'TestDrive:\folder' -ItemType Directory).FullName

        $global:Session = @{
            commands = @{
                list = @()
            }
            dryrun = $true
        }

        # Mock commands to check that they are being called
        # - Write-Error
        Mock -CommandName Write-Error -MockWith { }

        Mock -CommandName inspec -MockWith { }
    }

    Context "Initialize" {

        BeforeEach {
            # Reset the commands list to an empty array
            $global:Session.commands.list = @()
        }

        It "will error if no path has been specified" {
            { Invoke-Inspec -init } | Should -Throw "Path to the Inspec test files must be specified`nTask failed due to errors detailed above"

            Should -Invoke Write-Error
        }

        It "will error if the path to the files does not exist" {
            { Invoke-Inspec -init -path "pester" } | Should -Throw "Specfied path for Inspec files does not exist: pester`nTask failed due to errors detailed above"

            Should -Invoke Write-Error
        }

        It "will initialise inspec" {
            Invoke-Inspec -init -path $testFolder

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike "*inspec* init"
        }
    }

    Context "Execute" {

        BeforeEach {
            # Reset the commands list to an empty array
            $global:Session.commands.list = @()

            Remove-Item env:\INSPEC_ARGS -ErrorAction SilentlyContinue
        }

        It "will execute the tests for the specified cloud" {
            Invoke-Inspec -exec -path $testfolder -cloud azure

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike "*inspec* exec . -t azure:// --reporter cli"
        }

        it "will append any extra arguments to the command, if they are supplied as a string" {
            Invoke-Inspec -exec -path $testfolder -cloud azure -args "--input resource_group_name=myresources-euw"

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike "*inspec* exec . -t azure:// --reporter cli --input resource_group_name=myresources-euw"
        }

        it "will append any extra arguments to the command, if they are supplied as a command delimited list" {
            Invoke-Inspec -exec -path $testfolder -cloud azure -args "--input", "resource_group_name=myresources-euw"

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike "*inspec* exec . -t azure:// --reporter cli --input resource_group_name=myresources-euw"
        }

        it "will append any extra arguments to the command, if they are set as an environment variable" {

            # Set the environment variable
            $env:INSPEC_ARGS = "--input resource_group_name=myresources-euw"

            Invoke-Inspec -exec -path $testfolder -cloud azure

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike "*inspec* exec . -t azure:// --reporter cli --input resource_group_name=myresources-euw"
        }

        it "will append a reporter to the command if an output path is provided" {

            # Determine the output path based on the OS
            if ($isWindows) {
                $output = [IO.Path]::Combine($env:SystemDrive, "output", "tests")
            } else {
                $output = [IO.Path]::Combine("/", "output", "tests")
            }
            $expected = [IO.Path]::Combine($output, "inspec_tests_azure_folder.xml")

            Invoke-Inspec -exec -path $testfolder -cloud azure -output $output

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike ("*inspec* exec . -t azure:// --reporter cli junit2:{0}" -f $expected)

        }

        it "aill add the arguments to the command in the correct order" {

            Invoke-Inspec -exec -path $testfolder -cloud azure -arguments "--input resource_group_name=pester_resources --overwrite"

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike ("*inspec* exec . -t azure:// --reporter cli --overwrite --input resource_group_name=pester_resources")
        }
    }

    Context "Vendor" {

        BeforeEach {
            # Reset the commands list to an empty array
            $global:Session.commands.list = @()
        }

        it "will vendor the profile in the specified path" {

            Invoke-Inspec -vendor -path $testfolder

            # check that the generated command is correct
            $Session.commands.list[0] | Should -BeLike "*inspec* vendor ."
        }

        it "will overwrite existing vendor profile if specified" {

            Invoke-Inspec -vendor -path $testfolder -args "--overwrite"

            $Session.commands.list[0] | Should -BeLike "*inspec* vendor . --overwrite"
        }
    }
}
