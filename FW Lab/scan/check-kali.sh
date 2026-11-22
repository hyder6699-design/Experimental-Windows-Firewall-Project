#!/usr/bin/env bash
# Week 4 readiness check for KALI-01.  Usage: ./check-kali.sh
pass=0; fail=0
chk() {
  if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1"; fail=$((fail+1)); fi
}
chk "IP is 10.10.10.50/24"                 "ip -4 addr show | grep -q '10.10.10.50/24'"
chk "nmap installed"                        "command -v nmap"
chk "netcat installed"                      "command -v nc"
chk "No default route (lab is isolated)"    "! ip route | grep -q '^default'"
chk "Internet NOT reachable"                "! ping -c1 -W2 8.8.8.8"
chk "No Wi-Fi connection active"            "! nmcli -t -f TYPE,STATE dev | grep -q '^wifi:connected'"
chk "DC-01 reachable (TCP 389 LDAP)"        "nc -z -w2 10.10.10.10 389"
chk "WIN11-01 RDP open (before state)"      "nc -z -w2 10.10.10.21 3389"
chk "SRV-01 RDP open (before state)"        "nc -z -w2 10.10.10.22 3389"
chk "scan.sh present and executable"        "test -x ~/fw-lab/scan/scan.sh"
chk "Week 4 baseline scan saved"            "ls ~/fw-lab/results/scans/*week4-baseline-tcp.xml"
chk "RDP before-evidence saved"             "test -s ~/fw-lab/results/week4/rdp-before.txt"
echo
echo "$pass passed, $fail failed"
