
Describe "Invoke-Login" {

    BeforeAll {
        # Import the function under test
        . $PSScriptRoot/Invoke-Login.ps1

        # Import dependencies
        . $PSScriptRoot/../cloud/Connect-Azure.ps1
        . $PSScriptRoot/../cloud/Connect-EKS.ps1

        # Functions
        # Create function signatures that are used so that they can be mocked
        # This prevents the module from having to be present to run the commands
        function Import-AzAksCredential() {
            param (
                [string]
                $resourceGroupName,

                [string]
                $name
            )
        }

        # Mock commands
        # - Write-Error - mock this internal function to check that errors are being raised
        Mock -Command Write-Error -MockWith { return $MessageData } -Verifiable

        # Write-Debug is used for credential validation by AWS
        Mock -Command Write-Debug -Mockwith { return $MessageData }

        # - Connect-Azure - as we are just testing the functionality of the Invoke-Login function
        #                   connecting to Azure is not required and thus is mocked
        Mock -Command Connect-Azure -MockWith { return }
        # - Connect EKS -
        Mock -Command Connect-EKS -MockWith { return }
        # - Import-AzAksCredential
        Mock -Command Import-AzAksCredential -MockWith {}
    }

    BeforeEach {
        # Create a session object so that the Invoke-External function does not
        # execute any commands but the command that would be run can be checked
        $global:Session = @{
            commands = @{
                list = @()
            }
        }

    }

    AfterAll {
        Remove-Variable -Name Session -Scope Global
    }

    Context "No cloud platform is specified" {

        it "will error" {
            $ShouldParams = @{
                Throw = $true
                ExpectedMessage = "Parameter set cannot be resolved using the specified named parameters. One or more parameters issued cannot be used together or an insufficient number of parameters were provided."
                ExceptionType = ([System.Management.Automation.ParameterBindingException])
                # Command to run
                ActualValue = { Invoke-Login }
            }

            Should @ShouldParams
        }
    }

    Context "No cloud platform details are specified" {

        it "will error for azure" {
            Invoke-Login -azure
            Should -Invoke -CommandName Write-Error -Times 1
        }

        it "will error for aws" {
            Invoke-Login -aws
            Should -Invoke -CommandName Write-Error -Times 1
        }
    }

    Context "Azure" {

        it "will error without all required parameters" {

            Invoke-Login -azure -TenantId xxxx -SubscriptionId xxxx

            Should -Invoke -CommandName Write-Error -Times 1
        }

        it "will login to Azure" {

            $secure = ConvertTo-SecureString -AsPlainText -String xxxx
            Invoke-Login -azure -TenantId xxxx -SubscriptionId xxxx -username xxxx -password $secure

            Should -Invoke -CommandName Connect-Azure -Times 1
            Should -Invoke -CommandName Import-AzAksCredential -Times 0
        }

        it "will log into Azure and get AKS credentials" {

            $secure = ConvertTo-SecureString -AsPlainText -String xxxx
            Invoke-Login -azure -TenantId xxxx -SubscriptionId xxxx -username xxxx -password $secure -k8s -k8sname xxxx -resourceGroup yyyy

            Should -Invoke -CommandName Connect-Azure -Times 1
            Should -Invoke -CommandName Import-AzAksCredential -Times 1
        }
    }

    Context "AWS with arguments" {
        BeforeAll {
            # Mocking find-command as AWSCLI  may not exist on testing environment
            Mock -Command Find-Command -MockWith { return "aws" }
        }

        BeforeEach {
            # Reset the commands list to an empty array
            $global:Session.commands.list = @()
        }

        it "will error without all required parameters" {

            Invoke-Login -aws -key_secret "yyyy"

            Should -Invoke -CommandName Write-Error -Times 1
        }

        it "will validate login" {
            Invoke-Login -aws -key_id "xxxx" -key_secret "yyyy" -region "eu-west-2"

            Should -Invoke -CommandName Write-Debug -Times 1 # AWS Login validation is only outputted to debug stream
        }

        it "will validate login and get EKS credentials" {
            Invoke-Login -aws -key_id "xxxx" -key_secret "yyyy" -region "eu-west-2" -k8s -k8sname "zzzz"

            Should -Invoke -CommandName Write-Debug -Times 1 # AWS Login validation is only outputted to debug stream
            Should -Invoke -CommandName Connect-EKS -Times 1
        }
    }

    Context "AWS with env vars" {

        BeforeAll {

        # Backup any creds that may be in a local env
        $old_aws_access_key_id = $env:AWS_ACCESS_KEY_ID
        $old_aws_secret_access_key = $env:AWS_SECRET_ACCESS_KEY
        $old_aws_default_region = $env:AWS_DEFAULT_REGION


        $env:AWS_ACCESS_KEY_ID = "xxxx"
        $env:AWS_SECRET_ACCESS_KEY = "yyyy"
        $env:AWS_DEFAULT_REGION = "zzzz"
        # Mocking find-command as AWSCLI  may not exist on testing environment
        Mock -Command Find-Command -MockWith { return "aws" }
        }

        BeforeEach {
            # Reset the commands list to an empty array
            $global:Session.commands.list = @()
        }

        it "will validate login" {

            Invoke-Login -aws
            Write-Debug $($Session.commands.list| out-string)
            Should -Invoke -CommandName Write-Debug -Times 1 # Login validation is only outputted to debug stream
        }

        it "will validate login and get EKS credentials" {
            Invoke-Login -aws -k8s -k8sname "zzzz"
            Write-Debug $($Session.commands.list| out-string)
            Should -Invoke -CommandName Write-Debug -Times 1 # Login validation is only outputted to debug stream
            Should -Invoke -CommandName Connect-EKS -Times 1
        }

        AfterAll {
            # Restore any original AWS auth env vars for when this is run locally
            $env:AWS_ACCESS_KEY_ID = $old_aws_access_key_id
            $env:AWS_SECRET_ACCESS_KEY = $old_aws_secret_access_key
            $env:AWS_DEFAULT_REGION = $old_aws_default_region

            # Null transitional vars
            $old_aws_access_key_id = $null
            $old_aws_secret_access_key = $null
            $old_aws_default_region = $null
        }
    }

}
