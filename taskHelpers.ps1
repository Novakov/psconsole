function OnRemote([string]$ComputerName, [pscredential]$Credential = $null, [scriptblock]$Code)
{
    $params = @{ComputerName = $ComputerName}

    if($Credential -ne $null)
    {
        $params['Credential'] = $Credential
    }

    $session = New-PSSession @params

    if($hasLib) 
    {
        ls $libDirectory\*.ps1 | sort -Property BaseName | % {
            Invoke-Command -Session $session -FilePath $_
        }
    }

    Invoke-Command -Session $session -ScriptBlock $Code
}