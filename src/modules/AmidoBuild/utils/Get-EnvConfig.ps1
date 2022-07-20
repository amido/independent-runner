function Get-EnvConfig() {

    <#

    .SYNOPSIS
    Library function to read the environment configuration file

    .DESCRIPTION
    There are a couple of functions that need to read the environment configuration file. One is to
    check the environment `Confirm-Environment` and the other one is `New-EnvConfig` which will create
    a script, compatible with the local shell, that can be used to set the up the local environment
    to use with the Independent Runner

    #>

    [CmdletBinding()]
    param (

        [string]
        # Path to the environment configuration file
        $path,

        [string]
        # stage that is being executed
        $stage,

        [string]
        # Cloud platform that is being targetted
        $cloud

    )

    $missing = @()

    # Check that the specified path exists
    if (!(Test-Path -Path $path)) {
        Stop-Task -Message ("Specified file does not exist: {0}" -f $path)
    }

    $moduleName = "Powershell-Yaml"
    $module = Get-Module -ListAvailable -Name $moduleName
    if ([string]::IsNullOrEmpty($module)) {
        Stop-Task -Message "Please ensure that the Powershell-Yaml module is installed"
    } else {
        Import-Module -Name $moduleName
    }

    # Read in the specified file
    $stage_variables = Get-Content -Path $path -Raw
    $stageVars = ConvertFrom-Yaml -Yaml $stage_variables

    # Attempt to get the default variables to check for <-- TODO: Check for what?
    $required = @()
    if ($stageVars.ContainsKey("default")) {
        # get the default variables
        if ($stageVars["default"].ContainsKey("variables")) {
            $required += $stageVars["default"]["variables"]
                | Where-Object { $_.Required -ne $false -and ([string]::IsNullOrEmpty($_.cloud) -or $_.cloud -contains $cloud) }
                | ForEach-Object { $_ }
        }

        # Get the credentials for the cloud if they have been specified
        if ($stageVars["default"].ContainsKey("credentials") -and
            $stageVars["default"]["credentials"].ContainsKey($cloud)) {
            $required += $stageVars["default"]["credentials"][$cloud]
                | Where-Object { $_.Required -ne $false }
                | ForEach-Object { $_ }
        }
    }

    # If the stage is not null check that it exists int he stages list and if
    # it does merge with the required list
    if (![String]::IsNullOrEmpty($stage)) {

        # Attempt to get the stage from the file
        $_stage = $stageVars["stages"] | Where-Object { $_.Name -eq $stage }

        if ([String]::IsNullOrEmpty($_stage)) {
            Write-Warning -Message ("Specified stage is unknown: {0}" -f $stage)
        }
        else {
            $required += $_stage["variables"] | Where-Object { $_.Required -ne $false -and ([string]::IsNullOrEmpty($_.cloud) -or $_.cloud -contains $cloud) } | ForEach-Object { $_ }
        }

    }
    else {
        Write-Warning -Message "No stage has been specified, using default environment variables"
    }

    # ensure that required does not contain "empty" items
    $required = $required | Where-Object { $_.Name -match '\S' }

    # Iterate around all the required variables and ensure that they exist in enviornment
    # If any of them do not then add to the missing array
    foreach ($envvar in $required) {
        try {
            # In some cases all of the environment variables have been capitalised, this is to do with TaskCtl.
            # Check for the existence of the variable in UPPER case as well, if it exists create the var with
            # the correct name and then remove the UPPER case value
            $path = [IO.Path]::Combine("env:", $envvar.Name)
            $pathUpper = [IO.Path]::Combine("env:", $envvar.Name.ToUpper())

            if ((Test-Path -Path $pathUpper) -and !(Test-Path -Path $path)) {
                New-Item -Path $path -Value (Get-ChildItem -Path $pathUpper).Value
                Remove-Item -Path $pathUpper -Confirm:$false
            }

            $null = Get-ChildItem -path $path -ErrorAction Stop
        } catch {
            # The variable does not exist
            $missing += $envvar
        }
    }

    # return the required env vars
    return $missing
}
