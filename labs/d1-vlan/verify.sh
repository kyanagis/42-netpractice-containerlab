#!/usr/bin/env bash
# vlan の到達性/分離チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=vlan
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|同VLAN10 h1->h3 (trunk越え)|h1|ping -c1 -W1 10.0.0.3"
  "2|同VLAN20 h2->h4 (trunk越え)|h2|ping -c1 -W1 10.0.0.4"
  "3|別VLAN h1->h2 は遮断(同subnetでも不通)|h1|! ping -c1 -W1 10.0.0.2"
  "4|VLAN10 復路 h3->h1|h3|ping -c1 -W1 10.0.0.1"
)
run_checks
