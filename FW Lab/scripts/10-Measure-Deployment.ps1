#Requires -RunAsAdministrator
<#
.SYNOPSIS  Week 6 harness: deploy with one method, then poll the target until the
           checker passes. "Deployment time" = start of deploy -> first full pass.
           Run on DC-01. Revert the target to clean-baseline before EVERY run.
.EXAMPLE   .\10-Measure-Deployment.ps1 -Method PowerShell -Target WIN11-01 -Run 1
.NOTES     Safety: refuses to start if the target already has LAB rules or the
           FW-Baseline GPO is still linked (i.e. the target was not reverted).
#>
param(
    [Parameter(Mandatory)][ValidateSet('PowerShell','Netsh','GPO')][string]$Method,
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][int]$Run,
    [int]$TimeoutMinutes = 15,       # raise to 120 for natural (no -Force) GPO refresh
    [switch]$NoForce,                # GPO: wait for background refresh instead of forcing
    [switch]$SkipCleanCheck,         # only for deliberate experiments on a non-clean target
    [string]$OU  = 'OU=LabClients,DC=ehub,DC=com',
    [string]$Csv = (Join-Path $PSScriptRoot '..\results\deployment-runs.csv')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

function Open-TargetSession {
    # Retry until WinRM answers (target may still be booting after a revert)
    $deadline = (Get-Date).AddMinutes(5)
    while ($true) {
        try {
            $sess = New-PSSession -ComputerName $Target -ErrorAction Stop
            Invoke-Command $sess { Set-ExecutionPolicy -Scope Process Bypass -Force }
            return $sess
        } catch {
            if ((Get-Date) -gt $deadline) { throw "Cannot open a session to $Target : $_" }
            Write-Host "  waiting for $Target (WinRM not ready yet)..."
            Start-Sleep -Seconds 10
        }
    }
}

Write-Host "=== $Method run $Run on $Target ==="
$s = Open-TargetSession

# --- Clean-start guard ------------------------------------------------------
if (-not $SkipCleanCheck) {
    $labRules = Invoke-Command $s { @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName 'LAB*' -ErrorAction SilentlyContinue).Count }
    $gpoLinked = (Get-GPInheritance -Target $OU).GpoLinks.DisplayName -contains 'FW-Baseline'
    if ($labRules -gt 0 -or $gpoLinked) {
        Remove-PSSession $s
        throw "Target is NOT clean (LAB rules: $labRules, FW-Baseline linked: $gpoLinked). Revert $Target to clean-baseline and run 11-Remove-LabGPO.ps1 -Delete first."
    }
    Write-Host "  clean-start check passed (0 LAB rules, no FW-Baseline GPO)"
}

# --- Stage repo on target (not timed) ----------------------------------------
Invoke-Command $s { New-Item -ItemType Directory -Force C:\FWLab | Out-Null }
Copy-Item -ToSession $s -Path "$repo\config", "$repo\scripts" -Destination C:\FWLab -Recurse -Force

# --- Timed deployment ---------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
$deployOk = $true
try {
    switch ($Method) {
        'PowerShell' { $rc = Invoke-Command $s { & C:\FWLab\scripts\06-Deploy-PowerShell.ps1 *> $null; $LASTEXITCODE }; if ($rc) { $deployOk = $false } }
        'Netsh'      { $rc = Invoke-Command $s { cmd /c C:\FWLab\scripts\07-Deploy-Netsh.cmd *> $null; $LASTEXITCODE }; if ($rc) { $deployOk = $false } }
        'GPO'        {
            & "$PSScriptRoot\08-Deploy-GPO.ps1" *> $null
            if (-not $NoForce) { Invoke-Command $s { gpupdate /target:computer /force *> $null } }
        }
    }
} catch { $deployOk = $false; Write-Warning "Deployment step reported an error: $_" }
$scriptSeconds = $sw.Elapsed.TotalSeconds
Write-Host ("  deployment command finished after {0:N1} s; polling effective state..." -f $scriptSeconds)

# --- Poll the effective state (reconnect if WinRM drops during policy apply) ---
$skipMerge = $Method -ne 'GPO'
$reconnects = 0
$rc = 1
do {
    try {
        $rc = Invoke-Command $s -ArgumentList $skipMerge {
            param($skip) & C:\FWLab\scripts\09-Test-FirewallBaseline.ps1 -SkipMergeSettings:$skip -Quiet; $LASTEXITCODE
        }
        if ($rc -eq 0) { break }
    } catch {
        $reconnects++
        Write-Host "  session dropped ($reconnects) - reconnecting..."
        Remove-PSSession $s -ErrorAction SilentlyContinue
        $s = Open-TargetSession
    }
    Start-Sleep -Seconds 10
} while ($sw.Elapsed.TotalMinutes -lt $TimeoutMinutes)
$sw.Stop()

# --- Final detail (not timed) -----------------------------------------------------
$detail = Invoke-Command $s -ArgumentList $skipMerge {
    param($skip)
    Remove-Item C:\FWLab\last-check.csv -ErrorAction SilentlyContinue
    & C:\FWLab\scripts\09-Test-FirewallBaseline.ps1 -SkipMergeSettings:$skip -Quiet -OutCsv C:\FWLab\last-check.csv
    $r = Import-Csv C:\FWLab\last-check.csv
    [pscustomobject]@{
        Pass     = @($r | Where-Object Pass -eq 'True').Count
        Total    = $r.Count
        LabRules = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName 'LAB*').Count
        Sources  = (@(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName 'LAB*').PolicyStoreSourceType | Sort-Object -Unique) -join '+'
    }
}
Remove-PSSession $s

$row = [pscustomobject]@{
    Time             = Get-Date -Format o
    Method           = $Method
    Run              = $Run
    Target           = $Target
    ScriptReportedOK = $deployOk
    ScriptSeconds    = [math]::Round($scriptSeconds, 1)
    EffectiveSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    Converged        = ($rc -eq 0)
    SettingsPass     = $detail.Pass
    SettingsTotal    = $detail.Total
    LabRules         = $detail.LabRules
    RuleSource       = $detail.Sources
    Reconnects       = $reconnects
}
New-Item -ItemType Directory -Force (Split-Path $Csv) | Out-Null
$row | Export-Csv $Csv -NoTypeInformation -Append
$row | Format-List
