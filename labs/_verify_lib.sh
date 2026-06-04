#!/usr/bin/env bash
# 各verify.shがsourceする到達性チェック共通lib。runtime: LAB_RUNTIME=docker(既定)|linux
# containerlab docs: https://containerlab.dev/
set -euo pipefail

RUNTIME="${LAB_RUNTIME:-docker}"

# ラボノードはホストdockerに建つので直接 exec(docker/linux共通)
nexec() {
  local node="$1"; shift
  docker exec "clab-${LAB}-${node}" "$@"
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

# 深掘りラボ用の汎用チェック。CHECKS=("id|説明|node|sh -c で実行する判定コマンド")
# 判定コマンドはパイプ可(readの最終変数が残り全部を受ける)。exit0=OK。
run_checks() {
  local pass=0 total=0
  printf '\n  lab: %s (%s)\n' "$LAB" "$RUNTIME"
  printf '  %-4s %-30s %-8s %s\n' GOAL CHECK NODE RESULT
  printf -- '  ----------------------------------------------------------------\n'
  for g in "${CHECKS[@]}"; do
    IFS='|' read -r id desc node cmd <<<"$g"
    total=$((total+1))
    if docker exec "clab-${LAB}-${node}" sh -c "$cmd" >/dev/null 2>&1; then
      printf '  %-4s %-30s %-8s %s\n' "$id" "$desc" "$node" "[OK]"; pass=$((pass+1))
    else
      printf '  %-4s %-30s %-8s %s\n' "$id" "$desc" "$node" "[KO]"
    fi
  done
  printf -- '  ----------------------------------------------------------------\n'
  printf '  %d/%d checks pass\n\n' "$pass" "$total"
  [[ "$pass" -eq "$total" ]]
}
