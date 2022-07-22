# Scripts are provided AS IS without warranty of any kind.
# Use at your own risk.
# https://github.com/gkjono/SolarWinds-Tools

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
if (!(Test-Path -Path $ApiCredPath)) {
    $ApiCred = Get-Credential -Message "Please enter your credentials for SolarWinds Orion"
    if ($ApiCred) {
        Export-Clixml -Path $ApiCredPath -InputObject $ApiCred
    }
}
$SwCredential = Import-Clixml -Path $ApiCredPath -Verbose

# Checking to see if we have a cached an Orion server.
# If not, we'll prompt for hostname or IP address of the
# primary Orion server and cache it to the Orion environment variable.
if (!$Env:Orion) {
    $OrionServer = Read-Host "Enter the hostname or IP of your primary Orion server."
    if ($OrionServer) {
        New-Item -Path Env:\Orion -Value $OrionServer
    }
}
$Swis = Connect-Swis -Hostname $env:Orion -Credential $SwCredential

# Get nodes that don't currently have asset inventory polling enabled and have a polling method other than ICMP
$NodesQuery = @"
    SELECT CONCAT('<int>', NodeID, '</int>') AS col1
    FROM Orion.Nodes n
    WHERE n.ObjectSubType!='ICMP' AND (n.AssetInventory.Enabled IS NULL OR n.AssetInventory.Enabled='FALSE')
"@

$Nodes = Get-SwisData -SwisConnection $Swis -Query $NodesQuery


# Loop through each node and attempt to enable asset inventory polling.
# You are supposed to be able to pass this verb containing one array.
# However, I seem to get mixed results that way.
foreach ($Node in $Nodes) {
    $XML = @"
        <ArrayOfint xmlns:i="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/2003/10/Serialization/Arrays">$Node</ArrayOfint>
"@
    Invoke-SwisVerb -SwisConnection $Swis -EntityName Orion.AssetInventory.Polling -Verb EnablePollingForNodes -Arguments @(([xml]@($XML)).DocumentElement)
}