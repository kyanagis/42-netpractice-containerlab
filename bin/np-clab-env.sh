#!/usr/bin/env bash
# Shared setup for running containerlab through a Docker socket from inside the
# lab SSH container. The host daemon needs host-visible mount sources, not paths
# from the SSH container filesystem.

np_clab_in_container() {
  [[ -f /.dockerenv || -n "${container:-}" ]]
}

np_clab_current_container_id() {
  local cid

  if [[ -n "${NP_CLAB_CONTAINER_ID:-}" ]]; then
    printf '%s\n' "$NP_CLAB_CONTAINER_ID"
    return 0
  fi

  if [[ -n "${HOSTNAME:-}" ]] && docker inspect --type container "$HOSTNAME" >/dev/null 2>&1; then
    printf '%s\n' "$HOSTNAME"
    return 0
  fi

  cid="$(
    sed -n 's#^.*/\([0-9a-f]\{64\}\)$#\1#p' /proc/self/cgroup 2>/dev/null |
      head -1
  )"
  if [[ -n "$cid" ]] && docker inspect --type container "$cid" >/dev/null 2>&1; then
    printf '%s\n' "$cid"
    return 0
  fi

  return 1
}

np_clab_inspect_mounts() {
  local cid
  cid="$(np_clab_current_container_id)" || return 1

  docker inspect --format '{{range .Mounts}}{{printf "%s|%s|%s|%s\n" .Type .Name .Source .Destination}}{{end}}' "$cid"
}

np_clab_join_path() {
  local base="$1" rel="${2:-}"
  if [[ -z "$rel" ]]; then
    printf '%s\n' "$base"
  else
    printf '%s/%s\n' "${base%/}" "$rel"
  fi
}

np_clab_find_mount_for_path() {
  local path="$1"
  local best_type="" best_name="" best_source="" best_dest="" best_rel=""
  local best_len=-1 type name source dest rel len

  while IFS='|' read -r type name source dest; do
    [[ -n "$dest" ]] || continue
    case "$path" in
      "$dest") rel="" ;;
      "$dest"/*) rel="${path#"$dest"/}" ;;
      *) continue ;;
    esac

    len=${#dest}
    if ((len > best_len)); then
      best_len=$len
      best_type="$type"
      best_name="$name"
      best_source="$source"
      best_dest="$dest"
      best_rel="$rel"
    fi
  done < <(np_clab_inspect_mounts 2>/dev/null || true)

  [[ $best_len -ge 0 ]] || return 1
  printf '%s|%s|%s|%s|%s\n' "$best_type" "$best_name" "$best_source" "$best_dest" "$best_rel"
}

np_clab_configure_socket() {
  local mount type _name source _dest rel

  export DOCKER_SOCKET_HOST="${DOCKER_SOCKET_HOST:-/var/run/docker.sock}"
  [[ "$DOCKER_SOCKET_HOST" = "/var/run/docker.sock" ]] || return 0
  command -v docker >/dev/null 2>&1 || return 0

  mount="$(np_clab_find_mount_for_path /var/run/docker.sock || true)"
  [[ -n "$mount" ]] || return 0
  IFS='|' read -r type _name source _dest rel <<<"$mount"

  if [[ "$type" = "bind" && -n "$source" ]]; then
    export DOCKER_SOCKET_HOST
    DOCKER_SOCKET_HOST="$(np_clab_join_path "$source" "$rel")"
    export DOCKER_SOCKET_HOST
  fi
}

np_clab_auto_volume_name() {
  local cid suffix
  cid="$(np_clab_current_container_id 2>/dev/null || true)"
  suffix="${cid:-${HOSTNAME:-manual}}"
  suffix="${suffix#sha256:}"
  suffix="${suffix%%[!a-zA-Z0-9_.-]*}"
  suffix="${suffix:0:12}"
  printf '%s\n' "${NP_CLAB_AUTO_VOLUME:-np-repo-${suffix:-manual}}"
}

np_clab_configure_workspace() {
  local repo_dir="$1"
  local mount type name source dest rel host_repo volume

  if [[ -n "${CLAB_WORKSPACE_VOLUME:-}" ]]; then
    export NP_CLAB_MOUNT_SOURCE="$CLAB_WORKSPACE_VOLUME"
    export NP_CLAB_MOUNT_TARGET="${CLAB_WORKSPACE_TARGET:-$repo_dir}"
    export NP_CLAB_AUTOSYNC="${NP_CLAB_AUTOSYNC:-0}"
    return 0
  fi

  if [[ -n "${HOST_REPO_DIR:-}" ]]; then
    export NP_CLAB_MOUNT_SOURCE="$HOST_REPO_DIR"
    export NP_CLAB_MOUNT_TARGET="$repo_dir"
    export NP_CLAB_AUTOSYNC="${NP_CLAB_AUTOSYNC:-0}"
    return 0
  fi

  command -v docker >/dev/null 2>&1 || return 0

  mount="$(np_clab_find_mount_for_path "$repo_dir" || true)"
  if [[ -n "$mount" ]]; then
    IFS='|' read -r type name source dest rel <<<"$mount"
    case "$type" in
      volume)
        if [[ -n "$name" ]]; then
          export CLAB_WORKSPACE_VOLUME="$name"
          export NP_CLAB_MOUNT_SOURCE="$name"
          export NP_CLAB_MOUNT_TARGET="$dest"
          export NP_CLAB_AUTOSYNC=0
          return 0
        fi
        ;;
      bind)
        if [[ -n "$source" ]]; then
          host_repo="$(np_clab_join_path "$source" "$rel")"
          export HOST_REPO_DIR="$host_repo"
          export NP_CLAB_MOUNT_SOURCE="$host_repo"
          export NP_CLAB_MOUNT_TARGET="$repo_dir"
          export NP_CLAB_AUTOSYNC=0
          return 0
        fi
        ;;
    esac
  fi

  if np_clab_in_container; then
    volume="$(np_clab_auto_volume_name)"
    docker volume create "$volume" >/dev/null
    export CLAB_WORKSPACE_VOLUME="$volume"
    export NP_CLAB_MOUNT_SOURCE="$volume"
    export NP_CLAB_MOUNT_TARGET="$repo_dir"
    export NP_CLAB_AUTOSYNC="${NP_CLAB_AUTOSYNC:-1}"
    return 0
  fi

  return 0
}

np_clab_sync_workspace() {
  local repo_dir="$1"
  local helper image target

  [[ "${NP_CLAB_AUTOSYNC:-0}" = "1" ]] || return 0
  [[ -n "${CLAB_WORKSPACE_VOLUME:-}" ]] || return 0

  image="${CLAB_IMAGE:-ghcr.io/srl-labs/clab:0.75.0}"
  target="${NP_CLAB_MOUNT_TARGET:-$repo_dir}"
  helper="np-workspace-sync-${HOSTNAME:-manual}-$$"

  docker rm -f "$helper" >/dev/null 2>&1 || true
  if ! docker create \
    --name "$helper" \
    -v "${CLAB_WORKSPACE_VOLUME}:${target}" \
    --entrypoint /bin/sh \
    "$image" \
    -c 'repo=$1; mkdir -p "$repo"; rm -rf "$repo"/* "$repo"/.[!.]* "$repo"/..?*' \
    sh "$repo_dir" >/dev/null; then
    docker rm -f "$helper" >/dev/null 2>&1 || true
    return 1
  fi
  if ! docker start -a "$helper" >/dev/null; then
    docker rm -f "$helper" >/dev/null 2>&1 || true
    return 1
  fi
  if ! docker cp "${repo_dir}/." "${helper}:${repo_dir}/"; then
    docker rm -f "$helper" >/dev/null 2>&1 || true
    return 1
  fi
  docker rm "$helper" >/dev/null
}

np_clab_prepare_workspace() {
  local repo_dir="$1"
  np_clab_configure_socket
  np_clab_configure_workspace "$repo_dir"
  np_clab_sync_workspace "$repo_dir"
}
