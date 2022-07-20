class StopTaskException : System.Exception
{
    [int]$ExitCode

    StopTaskException(
        [int]$exitCode,
        [string]$message
    ) : Base($message) {
        $this.ExitCode = $exitCode
    }
}
