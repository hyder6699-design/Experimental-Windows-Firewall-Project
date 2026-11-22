#Requires -RunAsAdministrator
#Requires -Modules GroupPolicy, NetSecurity, ActiveDirectory
<#
.SYNOPSIS  Method C: build the FW-Baseline GPO on the DC and link it to the clients OU.
           Reuses scripts 02-05 with -PolicyStore pointing at the GPO.
.EXAMPLE   .\08-Deploy-GPO.ps1 -TargetOU 'OU=LabClients,DC=ehub,DC=com'
#>
param(
    [string]$GpoName  = 'FW-Baseline',
    [string]$TargetOU = 'OU=LabClients,DC=ehub,DC=com'
)
$ErrorActionPreference = 'Stop'
$here   = $PSScriptRoot
$domain = (Get-ADDomain).DNSRoot
$store  = "$domain\$GpoName"

if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $GpoName -Comment 'Windows Firewall lab baseline' | Out-Null
}

& "$here\02-Set-FirewallProfiles.ps1" -PolicyStore $store
& "$here\03-Set-FirewallLogging.ps1"  -PolicyStore $store
& "$here\04-Set-AdminRdpRules.ps1"    -PolicyStore $store
& "$here\05-Set-OutboundTestRule.ps1" -PolicyStore $store

if ((Get-GPInheritance -Target $TargetOU).GpoLinks.DisplayName -notcontains $GpoName) {
    New-GPLink -Name $GpoName -Target $TargetOU -LinkEnabled Yes | Out-Null
}
Write-Host "GPO '$GpoName' configured and linked to $TargetOU."
Write-Host 'Clients pick it up at next refresh (~90 min +/- 30) or: Invoke-GPUpdate -Computer <name> -Force'
