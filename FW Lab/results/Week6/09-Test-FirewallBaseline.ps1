<#
.SYNOPSIS  Compare the EFFECTIVE firewall state (ActiveStore) with Baseline.psd1.
.OUTPUTS   One object per setting (Id, Setting, Expected, Actual, Source, Pass).
           Exit code 0 = all pass, 1 = at least one fail.
.EXAMPLE   .\09-Test-FirewallBaseline.ps1 -OutCsv ..\results\check-WIN11-01.csv
#>
param(
    [string]$BaselinePath = (Join-Path $PSScriptRoot '..\config\Baseline.psd1'),
    [string]$OutCsv,
    [switch]$SkipMergeSettings,  # use for local-store methods (merge only exists in GPO)
    [switch]$PassThru,           # also emit the result objects (used by Pester)
    [switch]$Quiet               # no table or summary; exit code only (used by the Week 6 harness)
)
$b = Import-PowerShellDataFile $BaselinePath
$results = [System.Collections.Generic.List[object]]::new()
function Add-Result($id, $setting, $expected, $actual, $source) {
    $e = [Environment]::ExpandEnvironmentVariables("$expected")
    $a = [Environment]::ExpandEnvironmentVariables("$actual")
    $results.Add([pscustomobject]@{
        Id=$id; Setting=$setting; Expected="$expected"; Actual="$actual"; Source=$source
        Pass = ($e -ieq $a)
    })
}

# --- Profiles (effective) -------------------------------------------------
$active = Get-NetFirewallProfile -PolicyStore ActiveStore
$i = 0
foreach ($name in 'Domain','Private','Public') {
    $exp = $b.Profiles[$name]; $act = $active | Where-Object Name -eq $name
    foreach ($k in $exp.Keys | Sort-Object) {
        if ($SkipMergeSettings -and $k -like 'AllowLocal*') { continue }
        $i++
        Add-Result ('S{0:D2}' -f $i) "$name.$k" $exp[$k] $act.$k 'ActiveStore'
    }
}

# --- Rules (effective) ----------------------------------------------------
foreach ($r in $b.Rules) {
    $i++
    $rule = Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $r.DisplayName -ErrorAction SilentlyContinue |
            Select-Object -First 1
    $actual = if ($rule) { "$($rule.Enabled)/$($rule.Action)/$($rule.Direction)" } else { 'MISSING' }
    $src    = if ($rule) { "$($rule.PolicyStoreSourceType)" } else { '-' }
    Add-Result ('S{0:D2}' -f $i) "Rule: $($r.DisplayName)" "True/$($r.Action)/$($r.Direction)" $actual $src
}

# --- Audit policy ---------------------------------------------------------
foreach ($a in $b.Audit) {
    $i++
    $row = auditpol /get /subcategory:"$($a.Subcategory)" /r | ConvertFrom-Csv
    Add-Result ('S{0:D2}' -f $i) "Audit: $($a.Subcategory)" $a.Expected $row.'Inclusion Setting' 'auditpol'
}

# --- Service --------------------------------------------------------------
$i++
Add-Result ('S{0:D2}' -f $i) 'Service mpssvc running' 'Running' (Get-Service mpssvc).Status 'SCM'

$pass = ($results | Where-Object Pass).Count
if (-not $Quiet) {
    $results | Format-Table -AutoSize | Out-Host
    Write-Host ("{0}/{1} settings pass ({2:P0})" -f $pass, $results.Count, ($pass / $results.Count))
}
if ($OutCsv) {
    $results | Select-Object @{n='Computer';e={$env:COMPUTERNAME}}, @{n='Time';e={Get-Date -Format o}}, * |
        Export-Csv $OutCsv -NoTypeInformation -Append
}
if ($PassThru) { $results }
if ($pass -ne $results.Count) { exit 1 } else { exit 0 }
