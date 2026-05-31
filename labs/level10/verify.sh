#!/usr/bin/env bash
# level10のgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=level10
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|H1->H2|h1|157.42.103.3"
  "2|H3->H4|h3|157.42.103.131"
  "3|H1->Internet|h1|163.172.250.1"
  "4|H1->H4|h1|157.42.103.131"
  "5|H2->H3|h2|157.42.103.193"
  "6|H3->Internet|h3|163.172.250.1"
  "7|H4->Internet|h4|163.172.250.1"
)
run_goals
