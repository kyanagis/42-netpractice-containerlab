#!/usr/bin/env bash
# 02-switchのgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=switch
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|h1->h2|h1|10.10.10.2"
  "2|h1->h3|h1|10.10.10.3"
  "3|h2->h3|h2|10.10.10.3"
  "4|h3->h1|h3|10.10.10.1"
)
run_goals
