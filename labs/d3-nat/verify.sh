#!/usr/bin/env bash
# nat の検証(NAT到達 + ステートフルFW)。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=nat
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|SNAT: cli->ext (経路無い外へ到達)|cli|ping -c1 -W1 198.51.100.9"
  "2|DNAT: ext->gw:8080 が web:80 へ転送|ext|for i in \$(seq 1 10); do nc -z -w2 198.51.100.1 8080 && exit 0; sleep 1; done; exit 1"
  "3|FW: web(サーバ)からの外向きは遮断|web|! ping -c1 -W1 198.51.100.9"
  "4|FW: ext から web へ直接は不可|ext|! ping -c1 -W1 10.0.0.20"
)
run_checks
