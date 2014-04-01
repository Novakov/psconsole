param(
    [Parameter(ParameterSetName="invoke", Position=0)]
    [string]$TaskName = $null,

    [Parameter(ParameterSetName="invoke", ValueFromRemainingArguments = $true)]
    [Object[]]$args = @(),

    [Parameter(ParameterSetName="register")]
    [switch]$Register,

    [Parameter(ParameterSetName="register", Position=1)]
    [string]$Name
)

$baseDirectory = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

$libDirectory = "$($baseDirectory)\lib"

$hasLib = Test-Path $libDirectory

function invokeTask($taskName, $invocation, $taskArgs)
{        
    $taskFile = "$($baseDirectory)\tasks\$taskName.ps1"

    if(-not (Test-Path $taskFile))
    {
        Write-Error "Task $($taskName) not found"

        exit
    }

    if($hasLib)
    {
        ls "$($libDirectory)\*.ps1" | sort -Property BaseName | % {            
            . $_
        } 
    }     

    . $baseDirectory\taskHelpers.ps1

    $params = @()
    $callArgs = @()

    $script = "& '$taskFile' "

    for($i = 0; $i -lt $taskArgs.Length; $i++)
    {
        if($taskArgs[$i] -is [string])
        {
            $script += $taskArgs[$i] + ' '
        }
        else
        {
            $params += "`$arg_$i"
            $script+= "`$arg_$i "
            $callArgs += $taskArgs[$i]
        }
    }

    $paramDirective = $params -join ","

    $block = [scriptblock]::Create("param($paramDirective) $script")

    Invoke-Command -ScriptBlock $block -ArgumentList $callArgs
}

function taskList() 
{    
    return ls "$($baseDirectory)\tasks\*.ps1" | % {
        $help = Get-Help $_

        $description = ''

        if($help -is [string]) {
            $description = ''
        } else {
            $description = $help.Synopsis
        }

        New-Object psobject |
             Add-Member -MemberType NoteProperty -Name "Name" -Value $_.BaseName -PassThru |
             Add-Member -MemberType NoteProperty -Name "Description" -Value $description -PassThru
    }
}

function taskHelp($task)
{
    $scriptFile = "$($baseDirectory)\tasks\$task.ps1"

    if(Test-Path $scriptFile) 
    {
        $help = Get-Help $scriptFile

        if($help -is [string]) { return $help }

        $help.details.name = "$ConsoleName $task"

        foreach($syntax in $help.syntax.syntaxItem)
        {
            $syntax.name = "$ConsoleName $task"
        }

        $help
    } 
    else
    {
        taskList
    }
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
            "^$name\s+help\s+(.*)" {
                ls "$baseDir\tasks\*.ps1" | select -ExpandProperty BaseName
            }
            
            "^$name\s+(\S+)\s+(.*)" {                
                $targetScript = "$baseDir\tasks\$($Matches[1]).ps1"

                $completionLine = "$targetScript $($Matches[2])"

                $completions = TabExpansion2 -inputScript $completionLine -cursorColumn $completionLine.Length               

                return ($completions.CompletionMatches | select -ExpandProperty CompletionText)
            }    
        
            "^$name (.*)" {                 
                 $tasks = @(ls "$baseDir\tasks\*.ps1" | select -ExpandProperty BaseName) + @('help')
             
                 return $tasks
            }

            default {                
                if(Test-Path function:\tab_exp_backup_$Name) { & "tab_exp_backup_$Name" $line $lastWord }
            }
        }         
    }

    $_ = New-Item -Options AllScope -Path function: -Name global:TabExpansion -Value "param(`$line, `$lastWord) `n  return TabExpansion_$Name -name '$Name' -baseDir '$baseDirectory' -line `$line -lastWord `$lastWord" -Force
}
else
{
    $script:ConsoleName = $MyInvocation.InvocationName
    
    switch ($TaskName)
    {        
        'help' {
            $helpFor = $args[0]

            if($helpFor -eq $null) {
                taskList 
            } else {
                taskHelp $helpFor
            }
        }
        default { invokeTask $TaskName $MyInvocation $args }
    }
}
