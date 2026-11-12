#Requires -RunAsAdministrator
<#
.SYNOPSIS  Restrict RDP to the admin subnet.
.NOTES     Uses an allow rule for the admin subnet PLUS an explicit block for every
           other range. The explicit block is what makes this work no matter which
           store it lives in: the built-in "Remote Desktop" allow rules (remote = Any)
           would otherwise still let everyone in, because allow rules add up.
#>
param(
    [string]$PolicyStore = 'PersistentStore',
    [string]$BaselinePath = (Join-Path $PSScriptRoot '..\config\Baseline.psd1')
)
$ErrorActionPreference = 'Stop'
$b = Import-PowerShellDataFile $BaselinePath

foreach ($r in $b.Rules | Where-Object { $_.Name -like 'LAB-RDP-*' }) {
    $remote = switch ($r.RemoteAddress) { 'ADMIN' { $b.AdminSubnet } 'NONADMIN' { $b.NonAdminRanges } default { $_ } }

    # Idempotent: remove then recreate
    Remove-NetFirewallRule -PolicyStore $PolicyStore -Name $r.Name -ErrorAction SilentlyContinue

    New-NetFirewallRule -PolicyStore $PolicyStore -Name $r.Name -DisplayName $r.DisplayName `
        -Direction $r.Direction -Action $r.Action -Protocol $r.Protocol `
        -LocalPort $r.LocalPort -RemoteAddress $remote -Profile $r.Profile | Out-Null
    Write-Host "[$PolicyStore] rule $($r.Name) created"
}
