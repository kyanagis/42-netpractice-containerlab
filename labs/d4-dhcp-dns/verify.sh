#!/usr/bin/env bash
# dhcpdns の検証(DHCP取得 + ゲートウェイ配布 + DNS解決して到達)。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=dhcpdns
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|DHCP: 配布レンジのIPを取得|client|ip -4 addr show eth1 | grep -qE 'inet 10\\.0\\.0\\.1[0-5][0-9]'"
  "2|DHCP: 既定GW(opt3)を取得|client|ip -4 route | grep -q 'default via 10.0.0.1 dev eth1'"
  "3|DNS: dnsmasqが app.lab を解決|client|nslookup app.lab 10.0.0.1 | grep -q 10.0.0.20"
  "4|DNSで名前解決して到達: ->app.lab|client|ping -4 -c1 -W1 \$(getent hosts app.lab | awk '{print \$1}')"
)
run_checks
