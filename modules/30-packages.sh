#!/usr/bin/env bash
set -Eeuo pipefail

install_from_plan_file() {
  local kind="$1"
  local plan_file="$2"
  [[ -f "$plan_file" ]] || return 0
  mapfile -t packages < <(read_plan_file "$plan_file")
  [[ "${#packages[@]}" -gt 0 ]] || return 0
  printf '%s packages: %s\n' "$kind" "${#packages[@]}"
  package_install_idempotent "$kind" "${packages[@]}"
}

module_30_packages() {
  install_from_plan_file official "$PLAN_DIR/packages/official.pkgs"
  install_from_plan_file copr "$PLAN_DIR/packages/copr.pkgs"
  install_from_plan_file terra "$PLAN_DIR/packages/terra.pkgs"
  install_from_plan_file rpmfusion "$PLAN_DIR/packages/rpmfusion.pkgs"
  install_from_plan_file vendor "$PLAN_DIR/packages/vendor.pkgs"
  install_from_plan_file aur "$PLAN_DIR/packages/aur.pkgs"
  install_from_plan_file flatpak "$PLAN_DIR/flatpak/apps.flatpaks"
}

