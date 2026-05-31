#!/usr/bin/env bash
# 各verify.shがsourceする到達性チェック共通lib。runtime: LAB_RUNTIME=colima(既定)|docker|linux
# containerlab docs: https://containerlab.dev/
set -euo pipefail

RUNTIME="${LAB_RUNTIME:-colima}"
PROFILE="${CLAB_PROFILE:-clab}"
_filter() { grep -vE 'level=warning|delete ~/\.colima|config/colima' || true; }

nexec() {
  local node="$1"; shift
  if [ "$RUNTIME" = colima ]; then
    colima ssh -p "$PROFILE" -- docker exec "clab-${LAB}-${node}" "$@" 2> >(_filter >&2)
  else
    docker exec "clab-${LAB}-${node}" "$@"
  fi
}

run_goals() {
  local pass=0 total=0
  printf '\n  lab: %s (%s)\n' "$LAB" "$RUNTIME"
  printf '  %-4s %-18s %-8s %-18s %s\n' GOAL FLOW FROM TARGET RESULT
  printf -- '  ----------------------------------------------------------------\n'
  for g in "${GOALS[@]}"; do
    IFS='|' read -r id flow node target <<<"$g"
    total=$((total+1))
    if nexec "$node" ping -c1 -W1 "$target" >/dev/null 2>&1; then
      printf '  %-4s %-18s %-8s %-18s %s\n' "$id" "$flow" "$node" "$target" "[OK]"; pass=$((pass+1))
    else
      printf '  %-4s %-18s %-8s %-18s %s\n' "$id" "$flow" "$node" "$target" "[KO]"
    fi
  done
  printf -- '  ----------------------------------------------------------------\n'
  printf '  %d/%d goals reachable\n\n' "$pass" "$total"
  [[ "$pass" -eq "$total" ]]
}
