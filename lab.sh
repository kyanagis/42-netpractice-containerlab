#!/usr/bin/env bash
# NetPractice連動ラボのランナー。runtime: LAB_RUNTIME=docker(既定)|linux
# 穴埋め式: topo=配線のみ / solution.conf=模範解答 / problem.conf=穴埋め / verify.sh=到達性
# containerlab CLI docs: https://containerlab.dev/cmd/
set -euo pipefail

RUNTIME="${LAB_RUNTIME:-docker}"
CLAB_IMAGE="${CLAB_IMAGE:-ghcr.io/srl-labs/clab}"
DOCKER_SOCKET_HOST="${DOCKER_SOCKET_HOST:-/var/run/docker.sock}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_DIR="$REPO_DIR/labs"

if [[ -f "$REPO_DIR/bin/np-clab-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "$REPO_DIR/bin/np-clab-env.sh"
elif [[ -f /usr/local/lib/np-clab-env.sh ]]; then
  # shellcheck disable=SC1091
  source /usr/local/lib/np-clab-env.sh
fi

# containerlab を実行。linux=ホスト直接(sudo), docker=clab特権コンテナ。
clab() {
  if [ "$RUNTIME" = linux ]; then
    sudo containerlab "$@"
  else
    if declare -F np_clab_prepare_workspace >/dev/null; then
      np_clab_prepare_workspace "$REPO_DIR"
    fi
    local mount_args=()
    if [[ -n "${NP_CLAB_MOUNT_SOURCE:-}" ]]; then
      mount_args=(-v "${NP_CLAB_MOUNT_SOURCE}:${NP_CLAB_MOUNT_TARGET:-$REPO_DIR}")
    elif [[ -n "${CLAB_WORKSPACE_VOLUME:-}" ]]; then
      mount_args=(-v "${CLAB_WORKSPACE_VOLUME}:$REPO_DIR")
    else
      mount_args=(-v "${HOST_REPO_DIR:-$REPO_DIR}:$REPO_DIR")
    fi
    docker run --rm --privileged --network host --pid host \
      -v "$DOCKER_SOCKET_HOST:/var/run/docker.sock" \
      "${mount_args[@]}" -w "$REPO_DIR" \
      "$CLAB_IMAGE" containerlab "$@"
  fi
}

# ノード(コンテナ)内でコマンド実行。ラボノードはホストdockerに建つので直接 exec。
node_exec() { docker exec "$@"; }

require_runtime() {
  docker info >/dev/null 2>&1 || { echo "ERROR: dockerが動いていません。" >&2; exit 1; }
  if [ "$RUNTIME" = linux ]; then
    command -v containerlab >/dev/null 2>&1 || { echo "ERROR: containerlabが見つかりません。" >&2; exit 1; }
  fi
}

lab_dir()  { local d="$LABS_DIR/$1"; [[ -d "$d" ]] || { echo "ERROR: lab '$1' が見つかりません ('./lab.sh ls' で一覧)" >&2; exit 1; }; printf '%s' "$d"; }
require_lab() { lab_dir "$1" >/dev/null; }
topo_of()  { local t; t="$(lab_dir "$1")/topo.clab.yml"; [[ -f "$t" ]] || { echo "ERROR: $t がありません" >&2; exit 1; }; printf '%s' "$t"; }
labname_of() { local topo; topo="$(topo_of "$1")"; grep -E '^name:' "$topo" | head -1 | awk '{print $2}'; }
is_fillin()  { local d="$LABS_DIR/$1"; [[ -d "$d" && -f "$d/solution.conf" ]]; }

# 配線トポロジを(再)構築。L3設定は持たない白紙状態。
deploy_wiring() {
  local topo
  topo="$(topo_of "$1")"
  clab deploy -t "$topo" --reconfigure >/dev/null
}

# confファイルの各行をノード内で実行。書式: "<node>: <shで実行するコマンド>"
#  '#'始まりと空行は無視。'___'を含む行は未記入として実行をスキップ(警告)。
run_conf() {
  local name="$1" conf="$2" labname; labname="$(labname_of "$name")"
  local ran=0 blanks=0 fails=0 node cmd line
  [[ -f "$conf" ]] || { echo "ERROR: $conf がありません" >&2; exit 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    node="${line%%:*}"; cmd="${line#*:}"
    node="${node//[[:space:]]/}"
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    if [[ "$cmd" == *"___"* ]]; then
      printf '  [未記入] %-6s %s\n' "$node:" "$cmd" >&2; blanks=$((blanks+1)); continue
    fi
    if docker exec "clab-${labname}-${node}" sh -c "$cmd" >/dev/null 2>&1; then
      ran=$((ran+1))
    else
      printf '  [失敗]   %-6s %s\n' "$node:" "$cmd" >&2; fails=$((fails+1))
    fi
  done < "$conf"
  printf '  適用 %d 行' "$ran"
  [[ $blanks -gt 0 ]] && printf ' / 未記入 %d 箇所' "$blanks"
  [[ $fails  -gt 0 ]] && printf ' / 失敗 %d 行' "$fails"
  printf '\n'
}

# 配線を立て直し → confを適用 → 到達性チェック表示
build_and_verify() {
  local name="$1" conf="$2" dir; dir="$(lab_dir "$name")"
  deploy_wiring "$name"
  echo "$(basename "$conf") を適用:"
  run_conf "$name" "$conf" || true
  bash "$dir/verify.sh"
}

usage() {
  cat <<'EOF'
usage: ./lab.sh <command> [name] [node]   (runtime: LAB_RUNTIME=docker|linux)

  穴埋め学習ループ:
    apply <name>     problem.conf(自分の解答)を適用してgoal判定   ← 編集して何度も実行
    solve <name>     solution.conf(模範解答)を適用してgoal判定   ← 答え合わせ
    reset <name>     L3設定なしの白紙状態に戻す
    hint  <name>     READMEの図・与件・ヒントを表示

  運用:
    test  <name>     再構築せず到達性チェックのみ
    status <name>    clab inspect
    graph  <name>    トポロジ図(mermaid)
    shell  <name> <node>   ノードに入る
    down   <name>    撤去
    test-all         全ラボを solution で up->verify->down (CI用)
    ls               ラボ一覧

  編集対象: labs/<name>/problem.conf   (答えは labs/<name>/solution.conf)
EOF
}

list_labs() {
  echo "== 穴埋め(L2/L3): net_practice相当 =="
  for d in "$LABS_DIR"/*/; do
    [[ -f "$d/topo.clab.yml" && ! -f "$d/.deep" ]] || continue
    printf '  - %s\n' "$(basename "$d")"
  done
  echo "== 深掘り(完全版): L2/L3の先 =="
  for d in "$LABS_DIR"/*/; do
    [[ -f "$d/topo.clab.yml" && -f "$d/.deep" ]] || continue
    printf '  - %-14s %s\n' "$(basename "$d")" "$(sed -n 's/^# *[0-9a-z-]* *— *//p;q' "$d/README.md" 2>/dev/null)"
  done
}

cmd="${1:-}"; name="${2:-}"
case "$cmd" in
  apply)
    require_lab "$name"
    require_runtime
    is_fillin "$name" || { echo "ERROR: '$name' は穴埋めラボではありません" >&2; exit 1; }
    build_and_verify "$name" "$(lab_dir "$name")/problem.conf" ;;
  solve|reveal)
    require_lab "$name"
    require_runtime
    is_fillin "$name" || { echo "ERROR: '$name' は穴埋めラボではありません" >&2; exit 1; }
    build_and_verify "$name" "$(lab_dir "$name")/solution.conf" ;;
  reset)
    require_lab "$name"; require_runtime; deploy_wiring "$name"; echo "白紙状態にしました: $name (apply で解答を適用)" ;;
  up|deploy)
    require_lab "$name"
    require_runtime
    if is_fillin "$name"; then build_and_verify "$name" "$(lab_dir "$name")/problem.conf"
    else topo="$(topo_of "$name")"; clab deploy -t "$topo" --reconfigure; fi ;;
  down|destroy)   require_lab "$name"; require_runtime; topo="$(topo_of "$name")"; clab destroy -t "$topo" --cleanup ;;
  test)           require_lab "$name"; require_runtime; bash "$(lab_dir "$name")/verify.sh" ;;
  hint)
    require_lab "$name"
    f="$(lab_dir "$name")/README.md"
    [[ -f "$f" ]] && cat "$f" || echo "(READMEなし: $name)" ;;
  status|inspect) require_lab "$name"; require_runtime; topo="$(topo_of "$name")"; clab inspect -t "$topo" ;;
  graph)
    require_lab "$name"
    require_runtime
    topo="$(topo_of "$name")"
    clab graph -t "$topo" --offline --mermaid >/dev/null 2>&1 || true
    mmd="$(ls "$(lab_dir "$name")"/clab-*/graph/*.mermaid 2>/dev/null | head -1 || true)"
    if [[ -n "$mmd" && -f "$mmd" ]]; then cat "$mmd"; else clab inspect -t "$topo"; fi ;;
  shell)
    require_lab "$name"
    require_runtime
    node="${3:?usage: lab.sh shell <name> <node>}"
    labname="$(labname_of "$name")"
    node_exec -it "clab-${labname}-${node}" bash ;;
  test-all|all)
    require_runtime
    fail=0; failed=""
    for d in "$LABS_DIR"/*/; do
      [[ -f "$d/topo.clab.yml" ]] || continue
      n="$(basename "$d")"
      printf '\n===== %s =====\n' "$n"
      clab deploy -t "$d/topo.clab.yml" --reconfigure >/dev/null 2>&1
      if [[ -f "$d/solution.conf" ]]; then run_conf "$n" "$d/solution.conf" || true; fi
      bash "$d/verify.sh" || { fail=$((fail+1)); failed="$failed $n"; }
      clab destroy -t "$d/topo.clab.yml" --cleanup >/dev/null 2>&1
    done
    printf '\n===== test-all: 失敗%d件%s =====\n' "$fail" "${failed:+ ($failed)}"
    [[ $fail -eq 0 ]] ;;
  ls|list)           list_labs ;;
  ""|-h|--help|help) usage; echo; list_labs ;;
  *) echo "unknown command: $cmd" >&2; usage; exit 1 ;;
esac
