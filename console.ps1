param(
    [Parameter(ParameterSetName="invoke", Position=0)]
    [string]$TaskName = $null,

    [Parameter(ParameterSetName="invoke", ValueFromRemainingArguments = $true)]
    [Object[]]$args,

    [Parameter(ParameterSetName="register")]
    [switch]$Register,

    [Parameter(ParameterSetName="register", Position=1)]
    [string]$Name
)

$baseDirectory = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

function invokeTask($taskName, $invocation, $args)
{    
    $taskFile = "$($baseDirectory)\tasks\$taskName.ps1"

    if(-not (Test-Path $taskFile))
    {
        Write-Error "Task $($taskName) not found"

        exit
    }

    Invoke-Expression "$($taskFile) $($args)"
}


if($Register)
{    
    Write-Verbose "Registering TabExpansion"

    if(Test-Path function:\TabExpansion)
    {        
        echo "backing up"
        Rename-Item Function:\TabExpansion "global:tab_exp_backup_$Name" -Force
    }    

    Set-Alias $Name $MyInvocation.MyCommand.Definition -Scope Global

    $_ = New-Item -Options AllScope -Path function: -Name global:TabExpansion_$Name -Value {
        param($name, $baseDir, $line, $lastWord)

        $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()                    

        switch -regex ($lastBlock) {   
            "^$name\s+(\S+)\s+(.*)" {                
                $targetScript = "$baseDir\tasks\$($Matches[1]).ps1"

                $completionLine = "$targetScript $($Matches[2])"

                $completions = TabExpansion2 -inputScript $completionLine -cursorColumn $completionLine.Length               

                return ($completions.CompletionMatches | select -ExpandProperty CompletionText)
            }    
        
            "^$name (.*)" {                 
                 $tasks = ls "$baseDir\tasks\*.ps1" | select -ExpandProperty BaseName                   
             
                 return $tasks
            }

            default {                
                if(Test-Path function:\tab_exp_backup_$Name) { & "tab_exp_backup_$Name" $line,$lastWord }
            }
        }         
    }

    $_ = New-Item -Options AllScope -Path function: -Name global:TabExpansion -Value "param(`$line, `$lastWord) `n  return TabExpansion_$Name -name '$Name' -baseDir '$baseDirectory' -line `$line -lastWord `$lastWord" -Force
}
else
{
    switch($TaskName)
    {
        default { invokeTask $TaskName $MyInvocation @args }
    }
}