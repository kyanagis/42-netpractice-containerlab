#!/usr/bin/env bash
# level08のgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=level08
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|C->D|c|137.13.144.17"
  "2|D->C|d|137.13.144.1"
  "3|C->8.8.8.8|c|8.8.8.8"
  "4|D->8.8.8.8|d|8.8.8.8"
)
run_goals
