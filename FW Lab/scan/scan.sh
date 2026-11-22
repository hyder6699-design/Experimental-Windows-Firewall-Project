#!/usr/bin/env bash
# Run from the Linux/Kali VM.  Usage: ./scan.sh <label> [targets...]
# e.g. ./scan.sh week4-baseline 10.10.10.21 10.10.10.22
#      ./scan.sh ps-run3        10.10.10.21
set -euo pipefail
LABEL=${1:?label required}; shift
TARGETS=${*:-"10.10.10.21 10.10.10.22"}
OUT="../results/scans/$(date +%Y%m%d-%H%M%S)-$LABEL"
mkdir -p "$(dirname "$OUT")"

# -Pn: hosts drop ICMP when the firewall works; -sS: SYN scan; --reason shows WHY
# a port is open / closed (RST) / filtered (no reply = firewall drop).
sudo nmap -Pn -sS --reason -p 22,80,135,139,443,445,3389,5985,5986 $TARGETS -oA "$OUT-tcp"
sudo nmap -Pn -sU --reason -p 137,138,161,500 $TARGETS -oA "$OUT-udp"

echo "Saved: $OUT-tcp.{nmap,xml,gnmap} $OUT-udp.*"
# Compare two runs:  ndiff old-tcp.xml new-tcp.xml
