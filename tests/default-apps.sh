#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/zz-linux-setup-default-apps.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export XDG_STATE_HOME="$TEST_ROOT/state"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
export XDG_CONFIG_HOME="$TEST_ROOT/config"
export TARGET_USER="${USER:-$(id -un)}"
export TARGET_HOME="$TEST_ROOT/home"
mkdir -p "$TARGET_HOME"

# shellcheck source=../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../lib/idempotency.sh
source "$ROOT_DIR/lib/idempotency.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT_DIR/lib/packages.sh"
# shellcheck source=../lib/sources.sh
source "$ROOT_DIR/lib/sources.sh"
# shellcheck source=../lib/systemd.sh
source "$ROOT_DIR/lib/systemd.sh"
# shellcheck source=../lib/files.sh
source "$ROOT_DIR/lib/files.sh"
# shellcheck source=../lib/stow.sh
source "$ROOT_DIR/lib/stow.sh"
# shellcheck source=../lib/planner.sh
source "$ROOT_DIR/lib/planner.sh"
# shellcheck source=../lib/readiness.sh
source "$ROOT_DIR/lib/readiness.sh"
# shellcheck source=../modules/80-post-actions.sh
source "$ROOT_DIR/modules/80-post-actions.sh"

run_cmd_as_user() {
  local user="$1"
  shift
  printf '%s:%s\n' "$user" "$(printf '%q ' "$@")" >>"$TEST_ROOT/commands.log"
}

DISTRO=fedora
DRY_RUN=1
NO_TUI=1
build_plan_from_selections

configure_default_applications
grep -F 'xdg-mime default mpv.desktop video/mp4' "$TEST_ROOT/commands.log" >/dev/null
grep -F 'xdg-mime default mpv.desktop video/x-matroska' "$TEST_ROOT/commands.log" >/dev/null
grep -F 'xdg-mime default nvim.desktop text/plain' "$TEST_ROOT/commands.log" >/dev/null
! grep -F 'x-scheme-handler/mailto' "$TEST_ROOT/commands.log" >/dev/null

: >"$TEST_ROOT/commands.log"
set_category_override browsers firefox
configure_selected_browser_default
grep -F 'xdg-mime default firefox.desktop x-scheme-handler/http' "$TEST_ROOT/commands.log" >/dev/null
grep -F 'xdg-settings set default-web-browser firefox.desktop' "$TEST_ROOT/commands.log" >/dev/null

grep -F $'mpv.desktop\tpackage:mpv\tvideo/mp4' "$ROOT_DIR/config/default-applications.tsv" >/dev/null
grep -F $'org.gnome.Evolution.desktop\tdesktop-installed\tx-scheme-handler/mailto' "$ROOT_DIR/config/default-applications.tsv" >/dev/null

printf 'default apps ok\n'
