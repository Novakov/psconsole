param([string]$taskName = $null)

$base = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

$taskFile = "$($base)\tasks\$taskName.ps1"

if(-not (Test-Path $taskFile))
{
    Write-Error "Task $($taskName) not found"

    exit
}

Invoke-Expression "$($taskFile) $($MyInvocation.UnboundArguments)"
