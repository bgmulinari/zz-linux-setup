#!/usr/bin/env bash
set -Eeuo pipefail

package_file_for_kind() {
  case "$1" in
    official) printf '%s/packages/official.pkgs\n' "$PLAN_DIR" ;;
    copr) printf '%s/packages/copr.pkgs\n' "$PLAN_DIR" ;;
    terra) printf '%s/packages/terra.pkgs\n' "$PLAN_DIR" ;;
    rpmfusion) printf '%s/packages/rpmfusion.pkgs\n' "$PLAN_DIR" ;;
    vendor) printf '%s/packages/vendor.pkgs\n' "$PLAN_DIR" ;;
    aur) printf '%s/packages/aur.pkgs\n' "$PLAN_DIR" ;;
    flatpak) printf '%s/flatpak/apps.flatpaks\n' "$PLAN_DIR" ;;
    *) die "Unsupported plan package kind: $1" ;;
  esac
}

append_plan_entries() {
  local destination="$1"
  shift
  mkdir -p "$(dirname "$destination")"
  touch "$destination"
  local item
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    if ! grep -Fx "$item" "$destination" >/dev/null 2>&1; then
      printf '%s\n' "$item" >>"$destination"
    fi
  done
  sort -u "$destination" -o "$destination"
}

read_plan_file() {
  local plan_file="$1"
  [[ -f "$plan_file" ]] || return 0
  read_clean_lines "$plan_file" | sort -u
}

