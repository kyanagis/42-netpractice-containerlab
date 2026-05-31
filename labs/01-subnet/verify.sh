#!/usr/bin/env bash
# 01-subnetのgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=subnet
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|pc1->pc2|pc1|172.16.5.66"
  "2|pc2->pc1|pc2|172.16.5.65"
)
run_goals
