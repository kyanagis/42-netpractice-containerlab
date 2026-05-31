#!/usr/bin/env bash
# 03-routerのgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=router
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|h1->R(near)|h1|10.0.1.1"
  "2|h2->R(near)|h2|10.0.2.1"
  "3|h1->h2|h1|10.0.2.10"
  "4|h2->h1|h2|10.0.1.10"
)
run_goals
