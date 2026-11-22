#Requires -RunAsAdministrator
<#
.SYNOPSIS  Week 4 lab readiness check. Run on DC-01 as EHUB\Administrator.
           Checks DC-01, both targets (via remoting) and network reachability,
           and prints one PASS/FAIL line per setting.
.EXAMPLE   .\12-Check-LabState.ps1 -OutCsv C:\FWLab\results\week4\lab-state.csv
#>
param(
    [string[]]$Targets = @('WIN11-01', 'SRV-01'),
    [hashtable]$ExpectedIP = @{ 'DC-01' = '10.10.10.10'; 'WIN11-01' = '10.10.10.21'; 'SRV-01' = '10.10.10.22' },
    [string]$KaliIP = '10.10.10.50',
    [string]$Domain = 'ehub.com',
    [string]$NetBIOS = 'EHUB',
    [string]$OU = 'OU=LabClients,DC=ehub,DC=com',
    [string]$TimeZone = 'Eastern Standard Time',
    [string]$OutCsv
)

$results = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Machine, [string]$Check, $Expected, $Actual, $Pass = $null) {
    if ($null -eq $Pass) { $Pass = ("$Expected" -eq "$Actual") }
    $results.Add([pscustomobject]@{
        Machine = $Machine; Check = $Check; Expected = "$Expected"; Actual = "$Actual"; Pass = [bool]$Pass
    })
}

# ------------------------------------------------------------------ DC-01
$m = $env:COMPUTERNAME
Add-Check $m 'Hostname' 'DC-01' $m

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }).IPAddress -join ','
Add-Check $m 'IPv4 address' $ExpectedIP['DC-01'] $ip

$dns = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses).ServerAddresses -join ','
Add-Check $m 'DNS server (self)' '127.0.0.1 or 10.10.10.10' $dns ($dns -in '127.0.0.1', '10.10.10.10')

$ad = Get-ADDomain
Add-Check $m 'AD domain' $Domain $ad.DNSRoot
Add-Check $m 'NetBIOS name' $NetBIOS $ad.NetBIOSName

$aRec = (Resolve-DnsName "DC-01.$Domain" -Type A -ErrorAction SilentlyContinue).IPAddress -join ','
Add-Check $m 'DNS A record DC-01' $ExpectedIP['DC-01'] $aRec

$stale = @(Get-DnsServerResourceRecord -ZoneName $Domain -RRType A -ErrorAction SilentlyContinue |
           Where-Object { $_.RecordData.IPv4Address.IPAddressToString -notlike '10.10.10.*' }).Count
Add-Check $m 'No stale non-lab A records' 0 $stale

$ouOk = try { [bool](Get-ADOrganizationalUnit -Identity $OU) } catch { $false }
Add-Check $m 'OU LabClients exists' 'True' $ouOk

$inOU = if ($ouOk) { (Get-ADComputer -SearchBase $OU -Filter * | Sort-Object Name).Name -join ',' } else { '' }
Add-Check $m 'Computers in LabClients' (($Targets | Sort-Object) -join ',') $inOU

$links = if ($ouOk) { (Get-GPInheritance -Target $OU).GpoLinks.DisplayName } else { @() }
Add-Check $m 'FW-Audit GPO linked to OU' 'True' ($links -contains 'FW-Audit')
Add-Check $m 'FW-Baseline NOT linked (clean state)' 'True' ($links -notcontains 'FW-Baseline')

Add-Check $m 'Time zone' $TimeZone (Get-TimeZone).Id
Add-Check $m 'Repo at C:\FWLab' 'True' (Test-Path C:\FWLab\config\Baseline.psd1)

# ------------------------------------------------------------- Network (from DC-01)
Add-Check 'Network' "DC-01 -> Kali $KaliIP (ping)" 'True' (Test-Connection $KaliIP -Count 2 -Quiet)
foreach ($t in $Targets) {
    foreach ($port in 3389, 5985) {
        $ok = (Test-NetConnection $t -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded
        Add-Check 'Network' "DC-01 -> $t TCP $port" 'True' $ok
    }
}

# ------------------------------------------------------------- Targets (remoting)
$remote = Invoke-Command -ComputerName $Targets -ErrorAction SilentlyContinue -ErrorVariable remErr -ScriptBlock {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }).IPAddress -join ','
    $audit = foreach ($s in 'MPSSVC Rule-Level Policy Change', 'Filtering Platform Packet Drop', 'Filtering Platform Connection') {
        (auditpol /get /subcategory:"$s" /r | ConvertFrom-Csv).'Inclusion Setting'
    }
    $standby = (powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>$null |
                Select-String 'Current AC Power Setting Index') -replace '.*:\s*', ''
    $cs = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Hostname       = $env:COMPUTERNAME
        IP             = $ip
        DNS            = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses).ServerAddresses -join ','
        Domain         = if ($cs.PartOfDomain) { $cs.Domain } else { 'WORKGROUP' }
        NetProfile     = (Get-NetConnectionProfile).NetworkCategory -join ','
        RdpRegistry    = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
        RdpRuleOn      = [bool](Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue |
                                Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' })
        WinRM          = (Get-Service WinRM).Status.ToString()
        FwAllOn        = -not [bool](Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { $_.Enabled -ne 'True' })
        Audit          = $audit
        FwAuditApplied = ((gpresult /scope computer /r) -join "`n") -match 'FW-Audit'
        StandbyAC      = $standby
        Hibernate      = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -ErrorAction SilentlyContinue).HibernateEnabled
        TimeZone       = (Get-TimeZone).Id
        Repo           = Test-Path C:\FWLab\config\Baseline.psd1
        BeforeCsv      = Test-Path C:\FWLab\results\week4-before.csv
        LabRules       = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName 'LAB*' -ErrorAction SilentlyContinue).Count
    }
}

foreach ($t in $Targets) {
    $r = $remote | Where-Object PSComputerName -eq $t
    if (-not $r) {
        Add-Check $t 'Remoting reachable' 'True' 'False'
        continue
    }
    Add-Check $t 'Hostname' $t $r.Hostname
    Add-Check $t 'IPv4 address' $ExpectedIP[$t] $r.IP
    Add-Check $t 'DNS server' '10.10.10.10' $r.DNS
    Add-Check $t 'Domain joined' $Domain $r.Domain
    Add-Check $t 'Network profile' 'DomainAuthenticated' $r.NetProfile
    Add-Check $t 'RDP enabled (registry)' 0 $r.RdpRegistry
    Add-Check $t 'Remote Desktop firewall rule on' 'True' $r.RdpRuleOn
    Add-Check $t 'WinRM service' 'Running' $r.WinRM
    Add-Check $t 'Firewall on (all profiles)' 'True' $r.FwAllOn
    Add-Check $t 'Audit: MPSSVC Rule-Level Policy Change' 'Success and Failure' $r.Audit[0]
    Add-Check $t 'Audit: Filtering Platform Packet Drop' 'Failure' $r.Audit[1]
    Add-Check $t 'Audit: Filtering Platform Connection' 'Failure' $r.Audit[2]
    Add-Check $t 'FW-Audit GPO applied (gpresult)' 'True' $r.FwAuditApplied
    Add-Check $t 'Sleep disabled (AC)' '0x00000000 or n/a' $r.StandbyAC ($r.StandbyAC -in '0x00000000', '')
    Add-Check $t 'Hibernate disabled' 0 $r.Hibernate
    Add-Check $t 'Time zone' $TimeZone $r.TimeZone
    Add-Check $t 'Repo at C:\FWLab' 'True' $r.Repo
    Add-Check $t 'Week 4 before-CSV saved' 'True' $r.BeforeCsv
    Add-Check $t 'No LAB rules yet (clean state)' 0 $r.LabRules
}

# ------------------------------------------------------------- Report
$results | ForEach-Object {
    $flag = if ($_.Pass) { 'PASS' } else { 'FAIL' }
    $color = if ($_.Pass) { 'Green' } else { 'Red' }
    Write-Host ('{0}  {1,-9} {2,-42} expected: {3,-26} actual: {4}' -f $flag, $_.Machine, $_.Check, $_.Expected, $_.Actual) -ForegroundColor $color
}
$pass = @($results | Where-Object Pass).Count
Write-Host ''
Write-Host ("{0}/{1} checks pass" -f $pass, $results.Count) -ForegroundColor $(if ($pass -eq $results.Count) { 'Green' } else { 'Yellow' })
if ($OutCsv) { $results | Export-Csv $OutCsv -NoTypeInformation }
