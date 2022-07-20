

Describe "Invoke-Kubectl" {

    BeforeAll {
        . $PSScriptRoot/Invoke-Kubectl.ps1
        . $PSScriptRoot/Invoke-Login.ps1
        . $PSScriptRoot/../command/Find-Command.ps1
        . $PSScriptRoot/../command/Invoke-External.ps1

        # Create the testFolder
        $testFolder = (New-Item 'TestDrive:\folder' -ItemType Directory).FullName
        $manifestFile = Join-Path -Path $testFolder -ChildPath "manifest.yml"
        New-Item -ItemType File -Path $manifestFile

        $global:Session = @{
            commands = @{
                list = @()
            }
            dryrun = $true
        }

        Mock -CommandName Write-Error -Mockwith {}
        # Mock the Find-Command to return a valid path for the tool
        # This is so that the tool does not need to exist on the machine that is running the tests
        Mock -Command Find-Command -MockWith { return "kubectl" }

        $testclustername = "testcluster"
        $testclusteridentifier = "testclusteridentifier"

    }

    AfterAll {

        Remove-Variable -Name Session -Scope global
    }

    Context "No Parameters" {
        BeforeEach {

            Invoke-Kubectl -Apply -Arguments $manifestFile
        }

        It "should error" {
            Should -Invoke -CommandName Write-Error -Times 1
        }
    }

    # Azure

    Context "Azure Apply" {
        BeforeEach {
            Mock -CommandName Invoke-Login -MockWith { return } -RemoveParameterValidation tenantId -parameterFilter { $provider -eq 'azure' -and $k8s.IsPresent -and $identifier -eq $testclusteridentifier -and $target -eq $testclustername }
            Invoke-Kubectl -provider Azure -target $testclustername -identifier $testclusteridentifier -Apply -Arguments $manifestFile
        }

        It "will login to Azure and apply the relevant manifest to the target AKS cluster" {
            $Session.commands.list[0] | Should -BeLike "*kubectl* apply -f *manifest.yml"
            Should -Invoke -CommandName Invoke-Login -Times 1
        }
    }

    Context "Azure Custom" {

        BeforeEach {
            Mock -CommandName Invoke-Login -MockWith { return } -RemoveParameterValidation tenantId -parameterFilter { $provider -eq 'azure' -and $k8s.IsPresent -and $identifier -eq $testclusteridentifier -and $target -eq $testclustername }
            Invoke-Kubectl -provider Azure -target $testclustername -identifier $testclusteridentifier -Custom -Arguments "deploy"
        }
        It "will login to Azure and run a custom command on the target AKS cluster" {

            $Session.commands.list[1] | Should -BeLike "*kubectl* deploy"
            Should -Invoke -CommandName Invoke-Login -Times 1
        }
    }

    Context "Azure Rollout" {

        BeforeEach {
            Mock -CommandName Invoke-Login -MockWith { return } -RemoveParameterValidation tenantId -parameterFilter { $provider -eq 'azure' -and $k8s.IsPresent -and $identifier -eq $testclusteridentifier -and $target -eq $testclustername }
            Invoke-Kubectl -provider Azure -target $testclustername -identifier $testclusteridentifier -Rollout -Arguments "status -n pester deploy/pester --timeout 1200"
        }

        It "will login to Azure and run a rollout command on the target AKS cluster" {
            $Session.commands.list[2] | Should -BeLike "*kubectl* rollout status -n pester deploy/pester --timeout 1200"
            Should -Invoke -CommandName Invoke-Login -Times 1
        }
    }

    # AWS

    Context "AWS Apply" {
        BeforeEach {
            Mock -CommandName Invoke-Login -MockWith { return } -RemoveParameterValidation tenantId -parameterFilter { $provider -eq 'AWS' -and $k8s.IsPresent -and $identifier -eq $testclusteridentifier -and $target -eq $testclustername }
            Invoke-Kubectl -provider AWS -target $testclustername -identifier $testclusteridentifier -Apply -Arguments $manifestFile
        }

        It "will login to AWS and apply the relevant manifest to the target AKS cluster" {
            $Session.commands.list[0] | Should -BeLike "*kubectl* apply -f *manifest.yml"
            Should -Invoke -CommandName Invoke-Login -Times 1
        }
    }

    Context "AWS Custom" {

        BeforeEach {
            Mock -CommandName Invoke-Login -MockWith { return } -RemoveParameterValidation tenantId -parameterFilter { $provider -eq 'AWS' -and $k8s.IsPresent -and $identifier -eq $testclusteridentifier -and $target -eq $testclustername }
            Invoke-Kubectl -provider AWS -target $testclustername -identifier $testclusteridentifier -Custom -Arguments "deploy"
        }
        It "will login to Azure and run a custom command on the target AKS cluster" {

            $Session.commands.list[1] | Should -BeLike "*kubectl* deploy"
            Should -Invoke -CommandName Invoke-Login -Times 1
        }
    }

    Context "AWS Rollout" {

        BeforeEach {
            Mock -CommandName Invoke-Login -MockWith { return } -RemoveParameterValidation tenantId -parameterFilter { $provider -eq 'AWS' -and $k8s.IsPresent -and $identifier -eq $testclusteridentifier -and $target -eq $testclustername }
            Invoke-Kubectl -provider AWS -target $testclustername -identifier $testclusteridentifier -Rollout -Arguments "status -n pester deploy/pester --timeout 1200"
        }

        It "will login to AWS and run a rollout command on the target AKS cluster" {
            $Session.commands.list[2] | Should -BeLike "*kubectl* rollout status -n pester deploy/pester --timeout 1200"
            Should -Invoke -CommandName Invoke-Login -Times 1
        }
    }
}
