#!/usr/bin/env bash
# NetPractice連動ラボのランナー。runtime: LAB_RUNTIME=docker(既定)|linux
# containerlab CLI docs: https://containerlab.dev/cmd/
set -euo pipefail

RUNTIME="${LAB_RUNTIME:-docker}"
CLAB_IMAGE="${CLAB_IMAGE:-ghcr.io/srl-labs/clab}"
DOCKER_SOCKET_HOST="${DOCKER_SOCKET_HOST:-/var/run/docker.sock}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_DIR="$REPO_DIR/labs"

# containerlab を実行。linux=ホスト直接(sudo), docker=clab特権コンテナ。
clab() {
  if [ "$RUNTIME" = linux ]; then
    sudo containerlab "$@"
  else
    local mount_args=()
    if [[ -n "${CLAB_WORKSPACE_VOLUME:-}" ]]; then
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
  docker info >/dev/null 2>&1 || { echo "ERROR: dockerが動いていません。SETUP_docker.md参照。" >&2; exit 1; }
  if [ "$RUNTIME" = linux ]; then
    command -v containerlab >/dev/null 2>&1 || { echo "ERROR: containerlabが見つかりません。SETUP_linux.md参照。" >&2; exit 1; }
  fi
}

topo_of() {
  local t="$LABS_DIR/$1/topo.clab.yml"
  [[ -f "$t" ]] || { echo "ERROR: $t がありません" >&2; exit 1; }
  printf '%s' "$t"
}

labname_of() { grep -E '^name:' "$(topo_of "$1")" | head -1 | awk '{print $2}'; }

list_labs() {
  echo "labs:"
  for d in "$LABS_DIR"/*/; do
    [[ -f "$d/topo.clab.yml" ]] && printf '  - %s\n' "$(basename "$d")"
  done
}

usage() {
  cat <<'EOF'
usage: ./lab.sh <command> [name] [node]   (runtime: LAB_RUNTIME=docker|linux)
  up|down|test|status|graph <name>   構築/撤去/検証/一覧/図
  shell <name> <node>                ノードに入る
  test-all                           全ラボをup->test->down
  ls                                 ラボ一覧
EOF
}

cmd="${1:-}"; name="${2:-}"
case "$cmd" in
  up|deploy)      require_runtime; clab deploy  -t "$(topo_of "$name")" --reconfigure ;;
  down|destroy)   require_runtime; clab destroy -t "$(topo_of "$name")" --cleanup ;;
  test)           require_runtime; bash "$LABS_DIR/$name/verify.sh" ;;
  status|inspect) require_runtime; clab inspect -t "$(topo_of "$name")" ;;
  graph)
    require_runtime
    clab graph -t "$(topo_of "$name")" --offline --mermaid >/dev/null 2>&1 || true
    mmd="$(ls "$LABS_DIR/$name"/clab-*/graph/*.mermaid 2>/dev/null | head -1 || true)"
    if [[ -n "$mmd" && -f "$mmd" ]]; then cat "$mmd"; else clab inspect -t "$(topo_of "$name")"; fi ;;
  shell)
    require_runtime
    node="${3:?usage: lab.sh shell <name> <node>}"
    node_exec -it "clab-$(labname_of "$name")-${node}" bash ;;
  test-all|all)
    require_runtime
    fail=0; failed=""
    for d in "$LABS_DIR"/*/; do
      [[ -f "$d/topo.clab.yml" ]] || continue
      n="$(basename "$d")"
      printf '\n===== %s =====\n' "$n"
      clab deploy -t "$d/topo.clab.yml" --reconfigure >/dev/null 2>&1
      bash "$d/verify.sh" || { fail=$((fail+1)); failed="$failed $n"; }
      clab destroy -t "$d/topo.clab.yml" --cleanup >/dev/null 2>&1
    done
    printf '\n===== test-all: 失敗%d件%s =====\n' "$fail" "${failed:+ ($failed)}"
    [[ $fail -eq 0 ]] ;;
  ls|list)           list_labs ;;
  ""|-h|--help|help) usage; echo; list_labs ;;
  *) echo "unknown command: $cmd" >&2; usage; exit 1 ;;
esac
