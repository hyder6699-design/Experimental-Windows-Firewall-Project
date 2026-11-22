# Experimental Windows Firewall Project

Testing Windows Firewall settings that administrators push with scripts: the same baseline
deployed with **PowerShell**, **netsh** and **Group Policy**, verified by effective state,
network scans and logs.

## Repository layout

| Path | Contents |
|---|---|
| `config/Baseline.psd1` | Single source of truth: every profile setting, rule and audit setting |
| `scripts/00-01` | Backup and verified rollback |
| `scripts/02-05` | Profiles, logging, admin-only RDP, outbound block (each takes `-PolicyStore`) |
| `scripts/06-08` | Deployment methods: PowerShell (local), netsh (local), GPO (domain) |
| `scripts/09-Test-FirewallBaseline.ps1` | Checks the **effective** state (ActiveStore) against the baseline |
| `scripts/10-Measure-Deployment.ps1` | Week 6 timing harness |
| `scripts/11-Remove-LabGPO.ps1` | GPO rollback |
| `scripts/12-Check-LabState.ps1` | Lab readiness check (run on DC-01) |
| `scan/scan.sh`, `scan/check-kali.sh` | Nmap scans and Kali readiness check |
| `tests/Firewall.Tests.ps1` | Pester 5 wrapper around the checker |
| `results/` | Evidence by week: CSVs, transcripts, scans, screenshots |

## Lab

VMware Workstation, isolated LAN segment `FWLab` (no host, internet or DHCP).

| VM | OS | IP | Role |
|---|---|---|---|
| DC-01 | Windows Server 2022 | 10.10.10.10 | Domain controller (`ehub.com`), GPMC, test harness; inside admin subnet |
| WIN11-01 | Windows 11 Enterprise | 10.10.10.21 | Main target, OU `LabClients` |
| SRV-01 | Windows Server 2025 | 10.10.10.22 | Second target, OU `LabClients` |
| KALI-01 | Kali Linux | 10.10.10.50 | External scanner; outside admin subnet |

Admin subnet: `10.10.10.0/28`. Audit policy is applied by a separate `FW-Audit` GPO so only
firewall settings vary between methods.

## Running

Run only in the isolated lab, from `C:\FWLab\scripts`, in an elevated PowerShell session as
`EHUB\Administrator`. Revert targets to the `clean-baseline` snapshot between test runs.

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
Get-ChildItem C:\FWLab -Recurse | Unblock-File
.\09-Test-FirewallBaseline.ps1 -SkipMergeSettings     # local methods (31 items)
.\09-Test-FirewallBaseline.ps1                        # GPO method (33 items)
```

## Progress

- **Week 4**: lab built; readiness check 56/56; baseline checker 13/33 (before); baseline scans saved.
- **Week 5**: steps 1-5 complete (backup/rollback, profiles 16/31, logging 25/31, admin-only RDP,
  outbound block); script 02 bug found by the checker and fixed (`@args` -> `@params`).
