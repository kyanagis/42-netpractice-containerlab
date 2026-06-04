#!/usr/bin/env bash
# bgp の検証(eBGPで学習した経路でAS跨ぎ到達)。収束まで再試行。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=bgp
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|eBGP学習経路で ha->hc 到達(AS跨ぎ)|ha|for i in \$(seq 1 30); do ping -c1 -W1 10.2.0.10 >/dev/null 2>&1 && exit 0; done; exit 1"
  "2|r1がC(10.2.0.0/24)をBGP学習|r1|vtysh -c 'show ip route' | grep -qE '^B.*10.2.0.0/24'"
  "3|BGPセッション情報にpeerが居る|r1|vtysh -c 'show ip bgp summary' | grep -q '10.0.12.2'"
  "4|hc->ha 復路(AS跨ぎ)|hc|for i in \$(seq 1 5); do ping -c1 -W1 10.1.0.10 >/dev/null 2>&1 && exit 0; done; exit 1"
)
run_checks
