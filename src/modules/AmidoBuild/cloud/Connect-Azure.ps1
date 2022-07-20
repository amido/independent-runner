
function Connect-Azure() {

    <#

    .SYNOPSIS
    Connect to azure using environment variables for the parameters

    .DESCRIPTION
    In order to access resources and credentials in Azure, the AZ PowerShell module needs to connect
    to Azure using a Service Princpal. This cmdlet performs the login either by using data specified
    on the command line or by setting them as environment variables.

    This fuinction is not exported outside of the module.

    .EXAMPLE

    Connect to Azure using parameters set on the command line

    Connect-Azure -id 9bd211c0-92df-46d3-abb8-ba437f65096b -secret asd678asdlj9092314 -subscriptionId 77f2b631-0c5f-4bc9-a776-e8b0a5e7f5b8 -tenantId f0135c92-3088-40a7-8512-247762919ae1


    #>

    [CmdletBinding()]
    param (

        [Alias("clientid")]
        [string]
        # ID of the service principal
        $id = $env:ARM_CLIENT_ID,

        [string]
        # Secret for the service principal
        $secret = $env:ARM_CLIENT_SECRET,

        [string]
        # Subscription ID
        $subscriptionId = $env:ARM_SUBSCRIPTION_ID,

        [string]
        # Tenant ID
        $tenantId = $env:ARM_TENANT_ID

    )

    $result = Confirm-Parameters -list @("id", "secret", "subscriptionId", "tenantId")
    if (!$result) {
        return
    }

    # Create a secret to be used with the credential
    $pw = ConvertTo-SecureString -String $secret -AsPlainText -Force

    # Create the credential to log in
    $credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList ($id, $pw)

    Connect-AzAccount -Credential $credential -Tenant $tenantId -Subscription $subscriptionId -ServicePrincipal
}
