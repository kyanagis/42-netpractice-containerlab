#!/usr/bin/env bash
# level07のgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=level07
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|A->C|a|111.198.14.250"
  "2|C->A|c|111.198.14.2"
  "3|A->R1(near)|a|111.198.14.1"
  "4|C->R2(near)|c|111.198.14.249"
)
run_goals
