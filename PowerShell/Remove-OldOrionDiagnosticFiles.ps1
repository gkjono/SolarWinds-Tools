Get-ChildItem -Path "$ENV:ProgramData\SolarWinds\Diagnostics" | `
    Where-Object {$_.LastWriteTime -lt ((Get-Date).AddDays(-14)) -and $_.Extension -eq '.zip'} | `
    Remove-Item -Force -Confirm $false