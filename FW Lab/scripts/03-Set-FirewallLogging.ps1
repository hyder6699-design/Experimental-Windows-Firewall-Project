#Requires -RunAsAdministrator
<#
.SYNOPSIS  Per-profile firewall logging (file name, size, dropped + allowed packets).
#>
param(
    [string]$PolicyStore = 'PersistentStore',
    [string]$BaselinePath = (Join-Path $PSScriptRoot '..\config\Baseline.psd1')
)
$ErrorActionPreference = 'Stop'
$b = Import-PowerShellDataFile $BaselinePath

# Make sure the log folder exists on THIS machine (GPO targets create it at first log write).
if ($PolicyStore -eq 'PersistentStore') {
    New-Item -ItemType Directory -Force -Path "$env:SystemRoot\System32\LogFiles\Firewall" | Out-Null
}

foreach ($name in $b.Profiles.Keys) {
    $p = $b.Profiles[$name]
    Set-NetFirewallProfile -PolicyStore $PolicyStore -Profile $name `
        -LogFileName $p.LogFileName `
        -LogMaxSizeKilobytes $p.LogMaxSizeKilobytes `
        -LogBlocked $p.LogBlocked `
        -LogAllowed $p.LogAllowed
    Write-Host "[$PolicyStore] $name logging configured"
}
