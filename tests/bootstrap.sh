#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/zz-linux-setup-bootstrap.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

bootstrap_source="$(mktemp "$TEST_ROOT/bootstrap-source.XXXXXX")"
sed '$d' "$ROOT_DIR/bootstrap.sh" >"$bootstrap_source"

if command -v script >/dev/null 2>&1; then
  confirm_cmd="$(printf '%q' "source \"$bootstrap_source\"; ASSUME_YES=0; DRY_RUN=0; NO_TUI=1; bootstrap_confirm && exit 1 || exit 0")"
  confirm_output="$(printf 'n\n' | script -qfec "bash -lc $confirm_cmd" /dev/null 2>&1)"

  grep -F 'Continue with bootstrap? [y/N]' <<<"$confirm_output" >/dev/null
else
  printf 'bootstrap confirmation skipped (script command unavailable)\n'
fi

git -c init.defaultBranch=main init --bare "$TEST_ROOT/origin.git" >/dev/null
git -c init.defaultBranch=main init "$TEST_ROOT/source" >/dev/null
git -C "$TEST_ROOT/source" config user.email test@example.invalid
git -C "$TEST_ROOT/source" config user.name "Test User"
printf 'old\n' >"$TEST_ROOT/source/version.txt"
git -C "$TEST_ROOT/source" add version.txt
git -C "$TEST_ROOT/source" commit -m old >/dev/null
git -C "$TEST_ROOT/source" remote add origin "$TEST_ROOT/origin.git"
git -C "$TEST_ROOT/source" push -u origin main >/dev/null 2>&1

git clone "$TEST_ROOT/origin.git" "$TEST_ROOT/install" >/dev/null 2>&1
old_commit="$(git -C "$TEST_ROOT/install" rev-parse HEAD)"
printf 'new\n' >"$TEST_ROOT/source/version.txt"
git -C "$TEST_ROOT/source" commit -am new >/dev/null
git -C "$TEST_ROOT/source" push >/dev/null 2>&1
new_commit="$(git -C "$TEST_ROOT/source" rev-parse HEAD)"

source "$bootstrap_source"

DRY_RUN=1
need_sudo() { return 0; }
arch_bootstrap_output="$(bootstrap_arch)"
grep -F 'sudo pacman -Sy --needed --noconfirm ca-certificates curl git gum' <<<"$arch_bootstrap_output" >/dev/null
DRY_RUN=0

PACMAN_DB_LOCK="$TEST_ROOT/db.lck"
touch "$PACMAN_DB_LOCK"
lock_output="$(bootstrap_arch 2>&1)" && exit 1 || true
grep -F "Pacman database is locked: $PACMAN_DB_LOCK" <<<"$lock_output" >/dev/null
grep -F 'sudo fuser -v' <<<"$lock_output" >/dev/null
rm -f "$PACMAN_DB_LOCK"
unset PACMAN_DB_LOCK

REPO_URL="$TEST_ROOT/origin.git"
INSTALL_DIR="$TEST_ROOT/install"
REF="main"
clone_or_update_repo

[[ "$(git -C "$TEST_ROOT/install" rev-parse HEAD)" == "$new_commit" ]]
[[ "$(cat "$TEST_ROOT/install/version.txt")" == "new" ]]
[[ "$(git -C "$TEST_ROOT/install" rev-parse HEAD)" != "$old_commit" ]]

printf 'bootstrap ok\n'
