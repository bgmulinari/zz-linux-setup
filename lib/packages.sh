#!/usr/bin/env bash
set -Eeuo pipefail

native_backend_for_distro() {
  case "$1" in
    fedora) printf 'dnf\n' ;;
    *) die "Unsupported distro for native backend: $1" ;;
  esac
}

package_file_for_backend() {
  case "$1" in
    dnf) printf '%s/packages/dnf.pkgs\n' "$PLAN_DIR" ;;
    flatpak) printf '%s/flatpak/apps.flatpaks\n' "$PLAN_DIR" ;;
    action) printf '%s/actions/actions.list\n' "$PLAN_DIR" ;;
    *) die "Unsupported plan package backend: $1" ;;
  esac
}

prereq_file_for_backend() {
  case "$1" in
    dnf) printf '%s/prereqs/dnf.pkgs\n' "$PLAN_DIR" ;;
    flatpak) printf '%s/prereqs/flatpak.flatpaks\n' "$PLAN_DIR" ;;
    action) printf '%s/prereqs/actions.list\n' "$PLAN_DIR" ;;
    *) die "Unsupported prereq backend: $1" ;;
  esac
}

backend_prerequisite_backend() {
  case "$1" in
    dnf|action) return 1 ;;
    flatpak) native_backend_for_distro "$DISTRO" ;;
    *) die "Unsupported backend: $1" ;;
  esac
}

backend_prerequisite_items() {
  case "$1" in
    dnf|action) return 0 ;;
    flatpak)
      manifest_entries "$ROOT_DIR/packages/$DISTRO/official/flatpak.pkgs"
      ;;
    *)
      die "Unsupported backend: $1"
      ;;
  esac
}

append_plan_entries() {
  local destination="$1"
  shift
  mkdir -p "$(dirname "$destination")"
  touch "$destination"

  local -A seen=()
  local existing
  while IFS= read -r existing; do
    [[ -n "$existing" ]] || continue
    seen["$existing"]=1
  done <"$destination"

  local item
  local changed=0
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    [[ -n "${seen[$item]:-}" ]] && continue
    printf '%s\n' "$item" >>"$destination"
    seen["$item"]=1
    changed=1
  done
  [[ "$changed" -eq 0 ]] || sort -u "$destination" -o "$destination"
}

read_plan_file() {
  local plan_file="$1"
  [[ -f "$plan_file" ]] || return 0
  read_clean_lines "$plan_file" | sort -u
}
