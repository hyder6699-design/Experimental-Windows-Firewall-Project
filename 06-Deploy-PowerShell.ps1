#Requires -RunAsAdministrator
<#
.SYNOPSIS  Method A: deploy the full baseline to the LOCAL store with PowerShell.
           Run on the target (or via Invoke-Command from 10-Measure-Deployment.ps1).
#>
param([switch]$SkipBackup)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $SkipBackup) { $backup = & "$here\00-Backup-FirewallState.ps1" }

try {
    & "$here\02-Set-FirewallProfiles.ps1"
    & "$here\03-Set-FirewallLogging.ps1"
    & "$here\04-Set-AdminRdpRules.ps1"
    & "$here\05-Set-OutboundTestRule.ps1"
}
catch {
    Write-Error "Deployment failed: $_"
    if ($backup) { Write-Warning 'Rolling back...'; & "$here\01-Restore-FirewallState.ps1" -BackupDir $backup }
    exit 1
}
Write-Host 'PowerShell deployment finished. Verify with 09-Test-FirewallBaseline.ps1 (exit code matters, not this message).'
