#!/usr/bin/env bash
# mtu の検証(PMTU/フラグメント)。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=mtu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|小さいパケットは到達|h1|ping -c1 -W1 -s 1000 10.0.1.10"
  "2|大+DF は通らない(Frag needed/PMTU)|h1|! ping -c1 -W1 -M do -s 1450 10.0.1.10"
  "3|大-DF は分割されて到達|h1|ping -c1 -W1 -M dont -s 1450 10.0.1.10"
)
run_checks
