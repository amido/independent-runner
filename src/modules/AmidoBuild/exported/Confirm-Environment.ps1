function Confirm-Environment() {

    <#

    .SYNOPSIS
    Checks that all the environment variables have been configured

    .DESCRIPTION
    Most of the configuration for Stacks pipelines is done using environment variables
    and there can be quite a lot of them. This function uses a file in the repository to determine
    which environment variables are required for different stages and cloud platforms. If any
    environment variables are missing it will exit the task and stop the pipeline. This is
    so that things fail as early as possible.

    The structure of the file describing the envrionment is show below.

    default:
        variables: [{}]
        credentials:
            azure:  [{}]
            aws: [{}]

    stages:
        name: <NAME>
        variables: [{}]

    Each of the `[{}]` in variables denotes an array of the following object

        name: ""
        description: ""
        required: boolean
        cloud: <CLOUD>

    When thisd function runs it merges the default variables, the cloud cerdential variables
    and the stage variables and checks to see that they have been set. If they have not it will
    output a message stating whicch ones have not been set and then fail the task.

    .PARAMETER path
    Path to the file containing the stage environment variables

    .PARAMETER cloud
    Name of the cloud platform being deployed to. Can be set using thew
    `CLOUD_PLATFORM` environment variable. Currently only supports azure and aws.

    .PARAMETER stage
    Name of the stage to check the envirnment for. Can be set using the `STAGE` environnment
    variable.

    This variable is not checked for by this function as it is required by this function. If not
    specified a warning will be displayed stating that no stage has been specified amd will operate
    with the default variables.

    .PARAMETER passthru
    This forces the return of the missing variables as an object. It is up to the calling function
    to process this response and detremine if variables are missing.

    The primary use for this is for testing, but it can be used in other situations.

    .PARAMETER format
    Specifies the output format of the passthru. If not specified then a PSObject will be returned.

    If "json" is specifed the missing variables are returned in a JSON string


    #>

    [CmdletBinding()]
    param (

        [string]
        # Path to the file containing the list of environment variables
        # that must be set in the environment
        $path,

        [string]
        # Name of the cloud platform being deployed to. This is so that the credntial
        # environment variables are checked for correctly
        $cloud = $env:CLOUD_PLATFORM,

        [string]
        # Stage being run which determines the variables to be chcked for
        # This stage will be merged with the default check
        # If not specified then only the deafult stage will be checked
        $stage = $env:STAGE,

        [switch]
        # Pass the results throught the pipeline
        $passthru,

        [string]
        # Specify the output format if using the passthtu option, if not specfied
        # a PSObject is retruned
        $format
    )

    # Get a list of the required variables for this stage and the chosen cloud platform
    $missing = Get-EnvConfig -path $path -stage $stage -cloud $cloud

    # If there are missing values provide an error message and stop the task
    if ($missing.count -gt 0) {

        if ($passthru.IsPresent) {

            switch ($format) {
                "json" {
                    Write-Output (ConvertTo-Json $missing)
                    break
                }

                default {
                    $missing
                }
            }

        } else {

            # determine the length of the longest string
            $length = 0
            foreach ($item in $missing) {
                if ($item.name.length -gt $length) {
                    $length = $item.name.length
                }
            }

            $message = @()
            foreach ($item in $missing) {

                # determine how many whitespaces are required for this name lenght to pad it out
                $padding = $length - $item.name.length

                $sb = [System.Text.StringBuilder]::new()
                [void]$sb.Append($item.name)

                if (![string]::IsNullOrEmpty($item.description)) {
                    $whitespace = " " * $padding
                    [void]$sb.Append($whitespace)
                    [void]$sb.Append(" - {0}" -f $item.description)
                }

                $message += $sb.ToString()
            }

            # As there is an error the task in Taskctl needs to be stopped
            Stop-Task -Message ("The following environment variables are missing and must be provided:`n`t{0}" -f ($message -join "`n`t"))
        }
    }
}
