#!/usr/bin/env bash
# stp の検証(ループでも到達 + 冗長ポートが遮断)。収束まで再試行。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=stp
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|STP有効でループ環でも h1->h2 到達|h1|for i in \$(seq 1 40); do ping -c1 -W1 10.0.0.2 >/dev/null 2>&1 && exit 0; done; exit 1"
  "2|冗長リンク片側(sw3:eth2)がblocking(収束待ち)|sw3|for i in \$(seq 1 30); do bridge -d link show dev eth2 | grep -qi 'state blocking' && exit 0; sleep 1; done; exit 1"
  "3|h2->h1 復路|h2|for i in \$(seq 1 40); do ping -c1 -W1 10.0.0.1 >/dev/null 2>&1 && exit 0; done; exit 1"
)
run_checks
