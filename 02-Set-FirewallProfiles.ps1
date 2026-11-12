#Requires -RunAsAdministrator
<#
.SYNOPSIS  Profile state, default actions, notifications and rule-merge settings.
.PARAMETER PolicyStore
    PersistentStore (default) = local store, used by the PowerShell method.
    'lab.local\FW-Baseline'   = a domain GPO, used by 08-Deploy-GPO.ps1.
    localhost                 = the local GPO (optional variant).
#>
param(
    [string]$PolicyStore = 'PersistentStore',
    [string]$BaselinePath = (Join-Path $PSScriptRoot '..\config\Baseline.psd1')
)
$ErrorActionPreference = 'Stop'
$b = Import-PowerShellDataFile $BaselinePath

foreach ($name in $b.Profiles.Keys) {
    $p = $b.Profiles[$name]
    $params = @{
        PolicyStore           = $PolicyStore
        Profile               = $name
        Enabled               = $p.Enabled
        DefaultInboundAction  = $p.DefaultInboundAction
        DefaultOutboundAction = $p.DefaultOutboundAction
        NotifyOnListen        = $p.NotifyOnListen
    }
    if ($p.ContainsKey('AllowLocalFirewallRules')) {
        if ($PolicyStore -eq 'PersistentStore') {
            Write-Warning "$name merge settings only take effect in a GPO store - skipped for local store."
        } else {
            $params.AllowLocalFirewallRules = $p.AllowLocalFirewallRules
            $params.AllowLocalIPsecRules    = $p.AllowLocalIPsecRules
        }
    }
    Set-NetFirewallProfile @args
    Write-Host "[$PolicyStore] $name profile configured"
}
