@echo off
REM Method B: deploy the baseline to the LOCAL store with netsh.
REM Must stay in sync with config\Baseline.psd1 by hand.
REM Run from an elevated prompt. Back up first:  netsh advfirewall export C:\FWLab\pre-netsh.wfw

setlocal
set ADMIN=10.10.10.0/28
set NONADMIN=0.0.0.1-10.10.9.255,10.10.10.16-255.255.255.254

REM --- Profiles: state, default actions, notifications --------------------
netsh advfirewall set allprofiles state on || goto :fail
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound || goto :fail
netsh advfirewall set allprofiles settings inboundusernotification disable || goto :fail

REM --- Logging -----------------------------------------------------------
if not exist "%SystemRoot%\System32\LogFiles\Firewall" mkdir "%SystemRoot%\System32\LogFiles\Firewall"
netsh advfirewall set domainprofile  logging filename "%%SystemRoot%%\System32\logfiles\firewall\domainfw.log"  || goto :fail
netsh advfirewall set privateprofile logging filename "%%SystemRoot%%\System32\logfiles\firewall\privatefw.log" || goto :fail
netsh advfirewall set publicprofile  logging filename "%%SystemRoot%%\System32\logfiles\firewall\publicfw.log"  || goto :fail
netsh advfirewall set allprofiles logging maxfilesize 16384 || goto :fail
netsh advfirewall set allprofiles logging droppedconnections enable || goto :fail
netsh advfirewall set allprofiles logging allowedconnections enable || goto :fail

REM --- Merge settings (localfirewallrules/localconsecrules) are only valid in a
REM     GPO store, so netsh cannot set them on the local store. Recorded as a finding.

REM --- Rules (delete first so re-runs stay idempotent) --------------------
netsh advfirewall firewall delete rule name="LAB - RDP allow from admin subnet" >nul 2>&1
netsh advfirewall firewall delete rule name="LAB - RDP block from non-admin ranges" >nul 2>&1
netsh advfirewall firewall delete rule name="LAB - block outbound TCP 4444" >nul 2>&1

netsh advfirewall firewall add rule name="LAB - RDP allow from admin subnet" dir=in action=allow protocol=TCP localport=3389 remoteip=%ADMIN% profile=domain || goto :fail
netsh advfirewall firewall add rule name="LAB - RDP block from non-admin ranges" dir=in action=block protocol=TCP localport=3389 remoteip=%NONADMIN% profile=any || goto :fail
netsh advfirewall firewall add rule name="LAB - block outbound TCP 4444" dir=out action=block protocol=TCP remoteport=4444 profile=any || goto :fail

echo netsh deployment finished. Verify with 09-Test-FirewallBaseline.ps1
exit /b 0

:fail
echo netsh deployment FAILED at the command above. Roll back with: netsh advfirewall import C:\FWLab\pre-netsh.wfw
exit /b 1
