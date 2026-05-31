#!/usr/bin/env bash
# level09のgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=level09
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|A->B|a|11.0.0.3"
  "2|C->D|c|95.253.35.1"
  "3|A->Internet|a|163.172.250.1"
  "4|A->D|a|95.253.35.1"
  "5|B->C|b|12.0.0.2"
  "6|C->Internet|c|163.172.250.1"
  "7|D->A(return)|d|11.0.0.2"
  "8|C->B(return)|c|11.0.0.3"
)
run_goals
