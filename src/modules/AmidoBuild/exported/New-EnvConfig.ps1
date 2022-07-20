function New-EnvConfig() {

    <#

    .SYNOPSIS
    Creates a shell script that can be used to configure the environment variables
    for running the pipeline on a local workstation

    .DESCRIPTION
    A number of configuration items in the Indepdent Runner are set using enviornment variables.
    The `Confirm-Environment` function checks that these environment variables exist.

    This `New-EnvConfig` function is the companion function to `Confirm-Environment`. It uses
    the same configuration file and determines what the missing variables are and creates
    a relevant script file that can be edited to se5t the correct values.

    It is shell aware so if it detects PowerShell it will generate a PowerShell script, but if
    it is a Bash compatible shell it will create a bash script.

    It is cloud and stage aware so by providing these values you will get a script file
    for each of the cloud and stages as required.

    It is recommended that the resultant scripts are NOT checked into source control, so for
    this reason a `local/` directory should be created in the repo and added to the `.gitignore` file.
    All scripts can then be saved to the local folder without them being checked in.

    The shell detection works on a very simple rule, if a SHELL environment var exists then a Bash-like
    shell is assumed, if it does not exist then PowerShell is assumed.

    The filename of the script is determined by the ScriptPath, cloud, stage and detected shell.
    If the following function were run, in a PowerShell prompt:

        New-EnvConfig -Path /app/build/config/stage_envvars.yml -ScriptPath /app/local `
                      -Cloud Azure -Stage terraform_state

    The the script will be saved as:

        /app/local/envvars-azure-terraform_state.ps1

    .EXAMPLE

    The following example assumes that the command is being run in the Independent Pipeline,
    this the path is to the repo which is mapped to `/app` in the container

    PS> New-EnvConfig -Path /app/build/config/stage_envvars.yml -Cloud Azure -Stage terraform_state


    #>

    [CmdletBinding()]
    param (

        [string]
        # Path to the environment configuration file
        $path,

        [string]
        # Path to the the resulting script
        $scriptPath = $env:ENV_SCRIPT_PATH,

        [string]
        # Name of the cloud platform being deployed to. This is so that the credntial
        # environment variables are checked for correctly
        $cloud = $env:CLOUD_PLATFORM,

        [string]
        # Stage being run which determines the variables to be chcked for
        # This stage will be merged with the default check
        # If not specified then only the deafult stage will be checked
        $stage = $env:STAGE,

        [string]
        # Shell that the script should be generated for
        $shell = $env:SCRIPT_SHELL
    )

    $result = Confirm-Parameters -List @("path", "scriptpath")
    if (!$result) {
        return
    }

    # Check that the specified path exists
    if (!(Test-Path -Path $path)) {
        Stop-Task -Message ("Specified file does not exist: {0}" -f $path)
    }

    # Get a list of the missing variables for this stage and the chosen cloud platform
    $missing = Get-EnvConfig -path $path -stage $stage -cloud $cloud

    # Depending on the shell, set the preamble used in the script to configure the environment variables
    # This assumes that if the shell var does not exist then it is powershell, otherwise it assumes
    # a bash like environment
    if (Test-Path -Path env:\SHELL) {
        $preamble = "export "
        $extension = "sh"
    } else {
        $preamble = '$env:'
        $extension = "ps1"
    }

    $data = @()

    # Add the cloud platform to the script
    $data += "`# The Cloud platform for which these variables are being set"
    $data += '{0}CLOUD_PLATFORM="{1}"' -f $preamble, $cloud.ToLower()

    # Iterate around the missing variables
    foreach ($item in $missing) {

        # Add the description to the array
        $data += "`n# {0}" -f $item.description

        # Add the variable configuration
        $data += '{0}{1}=""' -f $preamble, $item.name
    }

    # Determine the name of the script file
    $filename = [IO.Path]::Combine($scriptPath, $("envvar-{0}-{1}.{2}" -f $cloud.ToLower(), $stage.ToLower(), $extension))

    # Set the contents of the file with the information in the $data var
    Set-Content -Path $filename -Value ($data -join "`n")
}
