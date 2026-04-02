#!/bin/bash
# gpu_alloc.sh
# 用法:
#   ./gpu_alloc.sh alloc <OWNER_ID>     # 返回形如 "2,5"
#   ./gpu_alloc.sh release <OWNER_ID>   # 释放该OWNER_ID占用
#
# 规则:
# - 仅分配 0-5 号GPU
# - 每次分配2张
# - 仅在“分配/释放临界区”持有flock
# - 无可用时每10秒重试，最多20分钟

set -euo pipefail

LOCK_FILE="/tmp/gpu_allocation.lock"
STATE_FILE="/tmp/gpu_allocation.state"

TIMEOUT=30
RETRY_INTERVAL=10
TOTAL_TIMEOUT=1200
MAX_RETRY=$((TOTAL_TIMEOUT / RETRY_INTERVAL))

GPU_POOL=(0 1 2 3 4 5)
REQUIRED=2

usage() {
  cat >&2 <<EOF
Usage:
  $0 alloc <OWNER_ID>
  $0 release <OWNER_ID>
EOF
  exit 1
}

ensure_state_file() {
  [ -f "$STATE_FILE" ] || : > "$STATE_FILE"
}

open_and_lock() {
  exec 200>"$LOCK_FILE" || {
    echo "ERROR: Cannot open lock file $LOCK_FILE" >&2
    exit 1
  }
  flock -x -w "$TIMEOUT" 200 || {
    echo "ERROR: Failed to acquire lock within ${TIMEOUT}s" >&2
    exec 200>&-
    exit 1
  }
}

unlock_and_close() {
  flock -u 200 || true
  exec 200>&- || true
}

cleanup_stale_locked() {
  # 清理不存在的PID记录（OWNER_ID按PID使用时生效）
  local tmp
  tmp="$(mktemp)"
  while IFS=: read -r owner gpus; do
    [ -z "${owner:-}" ] && continue
    if kill -0 "$owner" 2>/dev/null; then
      echo "${owner}:${gpus}" >> "$tmp"
    fi
  done < "$STATE_FILE"
  mv "$tmp" "$STATE_FILE"
}

is_reserved_locked() {
  local target="$1"
  awk -F: -v t="$target" '
    {
      n=split($2, a, ",");
      for (i=1; i<=n; i++) if (a[i]==t) found=1;
    }
    END { exit(found?0:1) }
  ' "$STATE_FILE"
}

alloc_two() {
  local owner_id="$1"
  local retry=0

  while true; do
    open_and_lock
    ensure_state_file
    cleanup_stale_locked

    local free=()
    local g
    for g in "${GPU_POOL[@]}"; do
      if ! is_reserved_locked "$g"; then
        free+=("$g")
      fi
    done

    if [ "${#free[@]}" -ge "$REQUIRED" ]; then
      local selected="${free[0]},${free[1]}"
      echo "${owner_id}:${selected}" >> "$STATE_FILE"
      unlock_and_close
      echo -n "$selected"
      exit 0
    fi

    unlock_and_close
    retry=$((retry + 1))
    if [ "$retry" -ge "$MAX_RETRY" ]; then
      echo "ERROR: Timeout(20min), no enough GPUs in state" >&2
      exit 1
    fi
    sleep "$RETRY_INTERVAL"
  done
}

release_owner() {
  local owner_id="$1"
  open_and_lock
  ensure_state_file

  local tmp
  tmp="$(mktemp)"
  awk -F: -v owner="$owner_id" '$1 != owner { print $0 }' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"

  unlock_and_close
}

main() {
  [ "$#" -eq 2 ] || usage
  local cmd="$1"
  local owner_id="$2"

  case "$cmd" in
    alloc) alloc_two "$owner_id" ;;
    release) release_owner "$owner_id" ;;
    *) usage ;;
  esac
}

main "$@"
