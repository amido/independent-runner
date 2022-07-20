Describe "Connect-Azure" {

    BeforeAll {

        # Import function under test
        . $PSScriptRoot/Connect-Azure.ps1

        # Import dependent functions
        . $PSScriptRoot/../utils/Confirm-Parameters.ps1

        # Mocks
        # - Write-Error
        Mock -CommandName Write-Error -MockWith {}

        # - Connect-AzAccount
        function Connect-AzAccount {}
        Mock -CommandName Connect-AzAccount -MockWith {}
    }

    Context "Use parameters" {

        It "will raise an error as not all the required params have been set" {

            Connect-Azure

            Should -Invoke -CommandName Write-Error -Times 1
        }

        It "will connect to Azure" {

            Connect-Azure -id xxxx -secret xxxx -subscriptionid xxxx -tenantid xxxx

            Should -Invoke -CommandName Connect-AzAccount -Times 1
        }
    }

    Context "Use enviornment variables" {

        BeforeAll {

            $env:ARM_CLIENT_ID = "xxxx"
            $env:ARM_CLIENT_SECRET = "xxxx"
            $env:ARM_SUBSCRIPTION_ID = "xxxx"
            $env:ARM_TENANT_ID = "xxxx"
        }

        AfterAll {

            Remove-Item env:\ARM_CLIENT_ID
            Remove-Item env:\ARM_CLIENT_SECRET
            Remove-Item env:\ARM_SUBSCRIPTION_ID
            Remove-Item env:\ARM_TENANT_ID
        }

        It "will connect to Azure" {

            Connect-Azure

            Should -Invoke -CommandName Connect-AzAccount -Times 1
        }
    }
}
