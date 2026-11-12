# Windows-Firewall-Experimentation-Project
# Windows Firewall Experimentation Lab

Scripts for testing Windows Firewall settings deployed via PowerShell, netsh and Group Policy.

- `config/Baseline.psd1`: the single source of truth for every setting.
- `scripts/`: run them in order from 00 to 11. See the implementation guide for the weekly workflow.
- `tests/Firewall.Tests.ps1`: `Invoke-Pester .\tests -Output Detailed`
- `scan/scan.sh`: Nmap runs from the Linux VM.
- `results/`: CSVs, scans and evidence go here. Commit the expected values before each test series.

Lab: `lab.local`, switch `FWLab`, admin subnet `10.10.10.0/28`.
DC-01 .10 · WIN11-01 .21 · SRV-01 .22 · KALI-01 .50

Run only in the isolated lab. Restore the `clean-baseline` checkpoints between runs.
