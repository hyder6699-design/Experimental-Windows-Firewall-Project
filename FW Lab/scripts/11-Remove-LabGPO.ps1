#Requires -Modules GroupPolicy
<#
.SYNOPSIS  Roll back the GPO method: unlink (and optionally delete) FW-Baseline,
           then force a refresh on the clients so policy settings are withdrawn.
#>
param(
    [string]$GpoName  = 'FW-Baseline',
    [string]$TargetOU = 'OU=LabClients,DC=ehub,DC=com',
    [string[]]$Computers = @('WIN11-01','SRV-01'),
    [switch]$Delete
)
Remove-GPLink -Name $GpoName -Target $TargetOU -ErrorAction SilentlyContinue | Out-Null
if ($Delete) { Remove-GPO -Name $GpoName -ErrorAction SilentlyContinue }
foreach ($c in $Computers) {
    Invoke-Command -ComputerName $c { gpupdate /target:computer /force | Out-Null }
    Write-Host "$c refreshed"
}
