#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_COMMAND="wizard"
DEFAULT_DISTRO="auto"
DEFAULT_TARGET_USER="${SUDO_USER:-$USER}"
DEFAULT_SYSTEM_SERVICES=(
  NetworkManager
  firewalld
  bluetooth
  chronyd
  power-profiles-daemon
)

BASE_BUNDLE_IDS_fedora=(
  base-bootstrap
  base-desktop-niri
  base-noctalia
  base-kitty
  base-desktop-core
  base-gtk-portals
  base-system-services
  base-desktop-apps
  base-file-integration
  base-wayland-tools
  base-gtk-look
)

BASE_BUNDLE_IDS_arch=(
  base-bootstrap
  base-desktop-core
  base-noctalia
  base-gtk-portals
  base-system-services
  base-desktop-apps
  base-file-integration
  base-wayland-tools
  base-gtk-look
  browser-firefox
)

SUPPORTED_DISTROS=(
  fedora
  arch
)
