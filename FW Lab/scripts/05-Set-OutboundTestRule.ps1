#Requires -RunAsAdministrator
<#
.SYNOPSIS  Outbound filtering test rule: block TCP 4444 to any host.
           Verified by running a listener on the Linux VM (nc -lvnp 4444).
#>
param(
    [string]$PolicyStore = 'PersistentStore',
    [string]$BaselinePath = (Join-Path $PSScriptRoot '..\config\Baseline.psd1')
)
$ErrorActionPreference = 'Stop'
$b = Import-PowerShellDataFile $BaselinePath
$r = $b.Rules | Where-Object Name -eq 'LAB-Block-Out-4444'

Remove-NetFirewallRule -PolicyStore $PolicyStore -Name $r.Name -ErrorAction SilentlyContinue
New-NetFirewallRule -PolicyStore $PolicyStore -Name $r.Name -DisplayName $r.DisplayName `
    -Direction $r.Direction -Action $r.Action -Protocol $r.Protocol `
    -RemotePort $r.RemotePort -Profile $r.Profile | Out-Null
Write-Host "[$PolicyStore] rule $($r.Name) created"
