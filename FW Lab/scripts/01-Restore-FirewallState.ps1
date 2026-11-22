#Requires -RunAsAdministrator
<#
.SYNOPSIS  Roll back to a backup made by 00-Backup-FirewallState.ps1.
.NOTES     Restores the LOCAL store and audit policy. Settings delivered by a GPO
           are rolled back by unlinking the GPO (11-Remove-LabGPO.ps1) + gpupdate.
#>
param([Parameter(Mandatory)][string]$BackupDir)

$ErrorActionPreference = 'Stop'
$wfw = Join-Path $BackupDir 'local-store.wfw'
if (-not (Test-Path $wfw)) { throw "No local-store.wfw in $BackupDir" }

netsh advfirewall import $wfw | Out-Null
auditpol /restore /file:"$(Join-Path $BackupDir 'auditpol.csv')" | Out-Null

# Verify: compare effective profiles now vs. at backup time
$before = Import-Clixml (Join-Path $BackupDir 'profiles-active.xml')
$now    = Get-NetFirewallProfile -PolicyStore ActiveStore
$props  = 'Enabled','DefaultInboundAction','DefaultOutboundAction','LogBlocked','LogAllowed','LogMaxSizeKilobytes'
$diff = foreach ($p in $before) {
    $n = $now | Where-Object Name -eq $p.Name
    foreach ($prop in $props) {
        if ("$($p.$prop)" -ne "$($n.$prop)") {
            [pscustomobject]@{ Profile=$p.Name; Setting=$prop; Backup="$($p.$prop)"; Now="$($n.$prop)" }
        }
    }
}
if ($diff) { Write-Warning 'Rollback incomplete:'; $diff | Format-Table; exit 1 }
Write-Host 'Rollback verified: effective profiles match the backup.'
