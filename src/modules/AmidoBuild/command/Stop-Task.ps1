
function Stop-Task() {

    <#

    .SYNOPSIS
    Stops a task being run in a Taskctl pipeline

    .DESCRIPTION
    When commands or other process fail in the pipeline, the entire pipeline must be stopped, it is not enough
    to call `exit` with an exit code as this does not stop the pipeline. It also causes issues when the module
    is run on a local development workstation as any failure will cause the console to be terminted.

    This function is intended to be used in place of `exit` and will throw a PowerShell exception after the
    error has been written out. This is will stop the pipeline from running and does not close the current
    console

    The function will also attempt to detect the pipeline that it is being run on and output the correct message
    string for that CI/CD platform.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        # Error message to be displayed
        $Message,
        [Parameter(Mandatory=$false)]
        [string]
        # Exit Code of the failing command or process
        $ExitCode = -1
    )

    $exceptionMessage = "Task failed due to errors detailed above"

    if (![string]::IsNullOrEmpty($Message)) {
        # Also prepend the message to the exception for easier catching
        $exceptionMessage = $Message + "`n" + $exceptionMessage

        # Attempt to detect the CI/CD the pipeline is running in and write out messages
        # in the correct format to be picked up the pipeline
        # For example if running in Azure DevOps then write a message according to the format
        #   "##[error]<MESSAGE>"
        # https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=bash

        #### Azure DevOps Detection
        $azdo = Get-ChildItem -Path env:\TF_BUILD -ErrorAction SilentlyContinue
        if (![String]::IsNullOrEmpty($azdo)) {
            $Message = "##[error]{0}" -f $Message
        }

        # Write an error
        # The throw method does not allow formatted text, so use Write-Error here to display a nicely formatted error
        Write-Error $Message
    }

    # Throw an exception to stop the process
    throw [StopTaskException]::new($exitCode, $exceptionMessage)
}
