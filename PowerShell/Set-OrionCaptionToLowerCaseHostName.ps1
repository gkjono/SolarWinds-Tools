# Verify that the OrionSDK is installed and available.
# This is a required prerequisite for this script.
# It can be downloaded from https://github.com/solarwinds/OrionSDK
if (!(Get-Command Get-SwisData)) {
    if (!(Get-PSSnapin | Where-Object { $_.Name -eq "SwisSnapin" })) {
        Try {
            Add-PSSnapin "SwisSnapin"
        } Catch {
            if (Test-Path "C:\Program Files (x86)\SolarWinds\Orion SDK\SWQL Studio\SwisPowerShell.dll") {
                C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe "C:\Program Files (x86)\SolarWinds\Orion SDK\SWQL Studio\SwisPowerShell.dll" | Out-Null
                C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe "C:\Program Files (x86)\SolarWinds\Orion SDK\SWQL Studio\SwisPowerShell.dll" | Out-Null
            } else {
                Write-Host "This script requires the OrionSDK to be installed." -ForegroundColor Red
                Write-Host "https://github.com/solarwinds/OrionSDK" -ForegroundColor Red
            }
        }
    }
}

# Checking to see if we already have stored credentials.
# If not, we'll prompt for credentials and securely
# store them with Export-CLIXML.
$ApiCredPath = $env:Userprofile + '\ApiCreds'
while (!(Test-Path -Path $ApiCredPath)) {
    $ApiCred = Get-Credential -Message "Please enter your credentials for SolarWinds Orion"
    if ($ApiCred) {
        Export-Clixml -Path $ApiCredPath -InputObject $ApiCred
    }
}
$SwCredential = Import-Clixml -Path $ApiCredPath -Verbose

# Checking to see if we have a cached an Orion server.
# If not, we'll prompt for hostname or IP address of the
# primary Orion server and cache it to the Orion environment variable.
while (!$Env:Orion) {
    $OrionServer = Read-Host "Enter the hostname or IP of your primary Orion server."
    if ($OrionServer) {
        New-Item -Path Env:\Orion -Value $OrionServer
    }
}
$Swis = Connect-Swis -Hostname $env:Orion -Credential $SwCredential

# Checking to see if we have set a path for where to keep the
# log files. If not, we'll prompt for a file path and create
# a new "ScriptLogPath" environment variable to cache it.
if (!($Env:ScriptLogPath)) {
    $ScriptLogPath = Read-Host "Enter the file path where you'd like to store your logs."
    New-Item -Path Env:\ScriptLogPath -Value $ScriptLogPath
}

if (!(Test-Path $Env:ScriptLogPath)) {
    New-Item -ItemType Directory -Path $Env:ScriptLogPath
}

# Roll Log if greater than 10 MB
if ((Get-Item -Path "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log" -ErrorAction SilentlyContinue).length -gt "10485760") {
    Remove-Item -Path "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log7" -Force -Confirm:$false -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log6" -NewName "Set-OrionCaptionToLowerCaseHostName.log7" -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log5" -NewName "Set-OrionCaptionToLowerCaseHostName.log6" -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log4" -NewName "Set-OrionCaptionToLowerCaseHostName.log5" -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log3" -NewName "Set-OrionCaptionToLowerCaseHostName.log4" -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Log\Set-OrionCaptionToLowerCaseHostName.log2" -NewName "Set-OrionCaptionToLowerCaseHostName.log3" -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Log\Set-OrionCaptionToLowerCaseHostName.log1" -NewName "Set-OrionCaptionToLowerCaseHostName.log2" -ErrorAction SilentlyContinue
    Rename-Item -Path "$Env:ScriptLogPath\Log\Set-OrionCaptionToLowerCaseHostName.log" -NewName "Set-OrionCaptionToLowerCaseHostName.log1" -ErrorAction SilentlyContinue
}

# This query finds nodes that have a FQDN as the caption and the node has a private IP. It changes them to lower case, removes the domain and sets them as the caption.
$FqdnNodesQuery = @"
    SELECT Caption, DNS, SysName, NodeName, DisplayName, uri
    FROM Orion.Nodes
    WHERE Caption LIKE '%[a-z]%' AND 
        Caption LIKE '%.%' AND
        Caption NOT LIKE '% %' AND
        (IP_Address LIKE '10.%' OR 
        IP_Address LIKE '192.168.%' OR 
        IP_Address LIKE '172.16.%' OR
        IP_Address LIKE '172.1[6-9].%' OR 
        IP_Address LIKE '172.2[0-9].%' OR 
        IP_Address LIKE '172.3[0-1].%')
"@

$NodeFQDN = Get-swisdata -SwisConnection $Swis -Query $FqdnNodesQuery

if ($NodeFQDN) {
    foreach ($Node in $NodeFQDN) {
        [string]$NewCaption = $($Node.Caption).ToLower().split('.')[0]
        if ($NewCaption) {
            "$(Get-Date) | $($Node.Caption) was renamed to $NewCaption" | Out-file "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log" -Append
            Set-SwisObject -SwisConnection $Swis -Uri $($Node.URI) -Properties @{ Caption=$NewCaption; }
            "$($Node.URI)"
        }
    }
}

# This query finds nodes that have any capital alphabetic character in it's caption and changes them to lower case.
$NodesWithCapitalLetters = Invoke-SwisVerb -SwisConnection $Swis -EntityName Orion.Reporting -Verb ExecuteSQL -Arguments @"
    SELECT NodeID,Caption,IP_Address from NodesData
    WHERE Caption LIKE '%[A-Z]%' COLLATE Latin1_General_BIN
"@

if ($NodesWithCapitalLetters.childnodes.documentelement.executesqlresults) {
    $SwisUri = Get-SwisData -SwisConnection $Swis -Query 'SELECT SettingValue FROM Orion.WebSettings WHERE SettingName=''SwisUriSystemIdentifier'''
    foreach ($Node in $NodesWithCapitalLetters.childnodes.documentelement.executesqlresults) {
        $URI = 'swis://' + $SwisUri + '/Orion/Orion.Nodes/NodeID=' + $($Node.NodeID)
        [string]$NewCaption = $($Node.Caption).ToLower()
        if ($NewCaption) {
            "$(Get-Date) | $($Node.Caption) was renamed to $NewCaption" | Out-file "$Env:ScriptLogPath\Set-OrionCaptionToLowerCaseHostName.log" -Append
            Set-SwisObject -SwisConnection $Swis -Uri $URI -Properties @{ Caption=$NewCaption; }
        }
    }
}
