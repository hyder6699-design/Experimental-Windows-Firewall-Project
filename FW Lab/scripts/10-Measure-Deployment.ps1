#Requires -RunAsAdministrator
<#
.SYNOPSIS  Week 6 harness: deploy with one method, then poll the target until the
           checker passes. "Deployment time" = start of deploy -> first full pass.
           Run on the DC. Restore the target's clean checkpoint before each run.
.EXAMPLE   .\10-Measure-Deployment.ps1 -Method GPO -Target WIN11-01 -Run 3
#>
param(
    [Parameter(Mandatory)][ValidateSet('PowerShell','Netsh','GPO')][string]$Method,
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][int]$Run,
    [int]$TimeoutMinutes = 15,       # raise to 120 for natural (no -Force) GPO refresh
    [switch]$NoForce,                # GPO: wait for background refresh instead of forcing
    [string]$Csv = (Join-Path $PSScriptRoot '..\results\deployment-runs.csv')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$s = New-PSSession -ComputerName $Target

# Stage repo on target (not timed)
Invoke-Command $s { New-Item -ItemType Directory -Force C:\FWLab | Out-Null }
Copy-Item -ToSession $s -Path "$repo\config","$repo\scripts" -Destination C:\FWLab -Recurse -Force

$sw = [Diagnostics.Stopwatch]::StartNew()
$deployOk = $true
switch ($Method) {
    'PowerShell' { $rc = Invoke-Command $s { & C:\FWLab\scripts\06-Deploy-PowerShell.ps1 | Out-Null; $LASTEXITCODE }; if ($rc) { $deployOk = $false } }
    'Netsh'      { $rc = Invoke-Command $s { cmd /c C:\FWLab\scripts\07-Deploy-Netsh.cmd | Out-Null; $LASTEXITCODE }; if ($rc) { $deployOk = $false } }
    'GPO'        {
        & "$PSScriptRoot\08-Deploy-GPO.ps1"
        if (-not $NoForce) { Invoke-Command $s { gpupdate /target:computer /force | Out-Null } }
    }
}
$deployReported = $sw.Elapsed.TotalSeconds

# Poll the effective state
$skipMerge = $Method -ne 'GPO'
do {
    $rc = Invoke-Command $s -ArgumentList $skipMerge {
        param($skip) & C:\FWLab\scripts\09-Test-FirewallBaseline.ps1 -SkipMergeSettings:$skip | Out-Null; $LASTEXITCODE
    }
    if ($rc -eq 0) { break }
    Start-Sleep -Seconds 10
} while ($sw.Elapsed.TotalMinutes -lt $TimeoutMinutes)
$sw.Stop()

$detail = Invoke-Command $s -ArgumentList $skipMerge {
    param($skip)
    Remove-Item C:\FWLab\last-check.csv -ErrorAction SilentlyContinue
    & C:\FWLab\scripts\09-Test-FirewallBaseline.ps1 -SkipMergeSettings:$skip -OutCsv C:\FWLab\last-check.csv | Out-Null
    $r = Import-Csv C:\FWLab\last-check.csv
    [pscustomobject]@{ Pass = ($r | Where-Object Pass -eq 'True').Count; Total = $r.Count }
}
Remove-PSSession $s

[pscustomobject]@{
    Time               = Get-Date -Format o
    Method             = $Method
    Run                = $Run
    Target             = $Target
    ScriptReportedOK   = $deployOk
    ScriptSeconds      = [math]::Round($deployReported, 1)
    EffectiveSeconds   = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    Converged          = ($rc -eq 0)
    SettingsPass       = $detail.Pass
    SettingsTotal      = $detail.Total
} | Tee-Object -Variable row | Export-Csv $Csv -NoTypeInformation -Append
$row | Format-List
