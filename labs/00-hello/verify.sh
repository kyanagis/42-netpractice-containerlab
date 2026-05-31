#!/usr/bin/env bash
# 00-helloのgoal到達性チェック。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=hello
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
GOALS=(
  "1|pc1->pc2|pc1|192.0.2.2"
  "2|pc2->pc1|pc2|192.0.2.1"
)
run_goals
