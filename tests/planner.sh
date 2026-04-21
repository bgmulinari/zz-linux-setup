#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_case() {
  local name="$1"
  shift
  local test_root
  test_root="$(mktemp -d "/tmp/zz-linux-setup-${name}.XXXXXX")"
  XDG_STATE_HOME="$test_root/state" \
  XDG_CACHE_HOME="$test_root/cache" \
  XDG_CONFIG_HOME="$test_root/config" \
  bash "$ROOT_DIR/install.sh" "$@"
}

fedora_browsers="$(run_case fedora-browsers print-plan --distro fedora --select browser=firefox,brave --dry-run)"
grep -F 'vendor:brave' <<<"$fedora_browsers" >/dev/null

fedora_chrome="$(run_case fedora-chrome print-plan --distro fedora --select browser=chrome --dry-run)"
grep -F 'vendor:google-chrome' <<<"$fedora_chrome" >/dev/null

fedora_zen="$(run_case fedora-zen print-plan --distro fedora --select browser=zen-flatpak --dry-run)"
grep -F 'flathub' <<<"$fedora_zen" >/dev/null

fedora_steam="$(run_case fedora-steam print-plan --distro fedora --select gaming=steam --dry-run)"
grep -F 'rpmfusion-free' <<<"$fedora_steam" >/dev/null
grep -F 'rpmfusion-nonfree' <<<"$fedora_steam" >/dev/null

arch_zen="$(run_case arch-zen print-plan --distro arch --select browser=zen-flatpak --dry-run)"
grep -F 'flathub' <<<"$arch_zen" >/dev/null

arch_base="$(run_case arch-base print-plan --distro arch --dry-run)"
grep -F 'aur' <<<"$arch_base" >/dev/null
grep -F 'noctalia-shell' <<<"$arch_base" >/dev/null
grep -F 'ghostty' <<<"$arch_base" >/dev/null

fedora_base="$(run_case fedora-base print-plan --distro fedora --dry-run)"
grep -F 'copr:yalter/niri' <<<"$fedora_base" >/dev/null
grep -F 'ghostty' <<<"$fedora_base" >/dev/null
! grep -F 'alacritty' <<<"$fedora_base" >/dev/null

printf 'planner ok\n'

