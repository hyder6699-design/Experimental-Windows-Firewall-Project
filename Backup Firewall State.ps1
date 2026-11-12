#Requires -RunAsAdministrator
<#
.SYNOPSIS  Back up the current firewall + audit state before any change.
.OUTPUTS   The backup folder path (pass it to 01-Restore-FirewallState.ps1).
#>
param([string]$Root = 'C:\FWLab\backups')

$ErrorActionPreference = 'Stop'
$dir = Join-Path $Root (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# 1. Local (persistent) store - restorable with netsh import
netsh advfirewall export (Join-Path $dir 'local-store.wfw') | Out-Null

# 2. Effective state (local + GPO merged) - for evidence / diffing
Get-NetFirewallProfile -PolicyStore ActiveStore |
    Export-Clixml (Join-Path $dir 'profiles-active.xml')
Get-NetFirewallRule -PolicyStore ActiveStore |
    Select-Object Name, DisplayName, Enabled, Direction, Action, Profile,
                  PolicyStoreSource, PolicyStoreSourceType |
    Export-Csv (Join-Path $dir 'rules-active.csv') -NoTypeInformation

# 3. Audit policy
auditpol /backup /file:"$(Join-Path $dir 'auditpol.csv')" | Out-Null

# 4. Policy registry branch (exists only when a GPO / local GPO sets firewall policy)
$polKey = 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall'
if (Test-Path "Registry::$polKey") {
    reg export $polKey (Join-Path $dir 'policy-firewall.reg') /y | Out-Null
}

Write-Host "Backup written to $dir"
$dir
