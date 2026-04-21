#!/usr/bin/env bash
set -Eeuo pipefail

ensure_supported_distro() {
  local distro="$1"
  local supported
  for supported in "${SUPPORTED_DISTROS[@]}"; do
    [[ "$supported" == "$distro" ]] && return 0
  done
  die "Unsupported distro: $distro"
}

normalize_distro() {
  if [[ "$DISTRO" == "auto" ]]; then
    DISTRO="$(detect_distro)" || die "Could not detect a supported distro from /etc/os-release"
  fi
  ensure_supported_distro "$DISTRO"
}

