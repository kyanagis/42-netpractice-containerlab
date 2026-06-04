#!/usr/bin/env bash
# ospf の検証。収束まで最大~40s 再試行(収束したら即合格)。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=ospf
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|OSPF学習経路で ha->hc 到達(収束待ち)|ha|for i in \$(seq 1 40); do ping -c1 -W1 10.3.0.10 >/dev/null 2>&1 && exit 0; done; exit 1"
  "2|r1がC(10.3.0.0/24)をOSPF学習|r1|vtysh -c 'show ip route' | grep -qE '^O.*10.3.0.0/24'"
  "3|hc->ha 復路|hc|for i in \$(seq 1 5); do ping -c1 -W1 10.1.0.10 >/dev/null 2>&1 && exit 0; done; exit 1"
)
run_checks
