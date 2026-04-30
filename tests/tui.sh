#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/zz-linux-setup-tui.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export XDG_STATE_HOME="$TEST_ROOT/state"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
export XDG_CONFIG_HOME="$TEST_ROOT/config"

# shellcheck source=../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../lib/tui.sh
source "$ROOT_DIR/lib/tui.sh"

sanitized="$(
  printf 'plain\033[31m red\033[0m\rprogress\033[2Kdone\n' | tui_sanitize_output_stream
)"

grep -F 'plain red' <<<"$sanitized" >/dev/null
grep -F 'progressdone' <<<"$sanitized" >/dev/null
! grep -q $'\033' <<<"$sanitized"
! grep -q $'\r' <<<"$sanitized"

printf 'tui ok\n'
