#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

violations="$(grep -RInE '(^|[[:space:]])(run_cmd[[:space:]]+sudo|sudo[[:space:]]+)(dnf|pacman|systemctl|chsh|rpm|usermod|python3|install|cp|tee|awk)\b' \
  "$ROOT_DIR/distros" "$ROOT_DIR/modules" "$ROOT_DIR/lib" \
  | grep -v 'lib/idempotency.sh' \
  | grep -v 'DRY-RUN:' \
  || true)"

if [[ -n "$violations" ]]; then
  printf 'raw privileged commands must use run_cmd_as_root or run_cmd_as_user:\n%s\n' "$violations" >&2
  exit 1
fi

grep -F 'run_cmd_as_user "$TARGET_USER" "$AUR_HELPER" -S --needed' "$ROOT_DIR/distros/arch.sh" >/dev/null

test_root="$(mktemp -d /tmp/zz-linux-setup-scope.XXXXXX)"
trap 'rm -rf "$test_root"' EXIT
if XDG_STATE_HOME="$test_root/state" XDG_CACHE_HOME="$test_root/cache" XDG_CONFIG_HOME="$test_root/config" \
  bash "$ROOT_DIR/install.sh" apply --dry-run --no-tui >/"$test_root/apply.out" 2>&1; then
  printf 'direct apply should be rejected\n' >&2
  exit 1
fi
grep -F 'apply is internal' "$test_root/apply.out" >/dev/null

printf 'scope ok\n'
