#!/usr/bin/env bash
set -Eeuo pipefail

module_80_post_actions() {
  if [[ "$DISTRO" == "fedora" && "$CODECS_SELECTED" -eq 1 ]]; then
    run_cmd sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    run_cmd sudo dnf group update -y multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin
  fi

  if array_contains "libvirt" $(effective_choice_ids "$DISTRO" "virtualization"); then
    run_cmd sudo usermod -aG libvirt "$TARGET_USER"
  fi

  run_cmd_as_user "$TARGET_USER" xdg-user-dirs-update || true
  run_cmd_as_user "$TARGET_USER" xdg-mime default org.kde.dolphin.desktop inode/directory || true
  run_cmd_as_user "$TARGET_USER" xdg-mime default org.kde.kwrite.desktop text/plain || true
  run_cmd_as_user "$TARGET_USER" xdg-mime default org.kde.okular.desktop application/pdf || true

  local -a browsers=()
  while IFS= read -r browser; do
    [[ -n "$browser" ]] && browsers+=("$browser")
  done < <(effective_choice_ids "$DISTRO" "browsers")

  local browser_choice=""
  if [[ -n "$PREFERRED_BROWSER" ]]; then
    browser_choice="$PREFERRED_BROWSER"
  elif [[ "${#browsers[@]}" -eq 1 ]]; then
    browser_choice="${browsers[0]}"
  fi
  if [[ -n "$browser_choice" ]]; then
    local desktop_file=""
    desktop_file="$(browser_desktop_file "$browser_choice" || true)"
    if [[ -n "$desktop_file" ]]; then
      run_cmd_as_user "$TARGET_USER" xdg-settings set default-web-browser "$desktop_file" || log_warn "Could not set default browser to $desktop_file"
    fi
  fi
}

