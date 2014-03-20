if(Test-Path function:\TabExpansion)
{
    echo 'backuping tab expansion'

    ls function:\tab*

    Rename-Item Function:\TabExpansion console_tab_backup
}

Set-Alias console D:\Coding\Powershell\console\console.ps1 -Scope Global

$global:base = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

function global:getTasks($lastWord)
{        
    return (ls "$base\tasks\*.ps1" | select -ExpandProperty BaseName)
}

function global:TabExpansion($line, $lastWord)
{
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()            

    switch -regex ($lastBlock) {   
        '^console\s+(\S+)\s+(.*)' {
            $targetScript = "$base\tasks\$($Matches[1]).ps1"

            $completionLine = "$targetScript $($Matches[2])"

            $completions = TabExpansion2 -inputScript $completionLine -cursorColumn $completionLine.Length

            $Host.UI.RawUI.WindowTitle = $targetScript

            return ($completions.CompletionMatches | select -ExpandProperty CompletionText)
        }    
        
        '^console (.*)' {
             $tasks = (getTasks $lastWord)                        
             
             return $tasks
        }

        default { if(Test-Path function:\console_tab_backup) { console_tab_backup($line, $lastWord) }}
    }    
}