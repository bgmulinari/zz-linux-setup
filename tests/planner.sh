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
  LOG_DIR="$test_root/logs" \
  bash "$ROOT_DIR/install.sh" "$@"
}

run_install_case() {
  local name="$1"
  shift
  local test_root
  test_root="$(mktemp -d "/tmp/zz-linux-setup-install-${name}.XXXXXX")"
  XDG_STATE_HOME="$test_root/state" \
  XDG_CACHE_HOME="$test_root/cache" \
  XDG_CONFIG_HOME="$test_root/config" \
  LOG_DIR="$test_root/logs" \
  bash "$ROOT_DIR/install.sh" install "$@" --dry-run 2>&1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  grep -F "$needle" <<<"$haystack" >/dev/null
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  ! grep -F "$needle" <<<"$haystack" >/dev/null
}

fedora_base="$(run_case fedora-base print-plan --distro fedora --dry-run)"
assert_contains "$fedora_base" 'base-source-rpmfusion-free'
assert_contains "$fedora_base" 'base-source-rpmfusion-nonfree'
assert_contains "$fedora_base" 'base-source-cisco-openh264'
assert_contains "$fedora_base" 'base-source-flathub'
assert_contains "$fedora_base" 'terra'
assert_not_contains "$fedora_base" 'vendor:vscode'
assert_not_contains "$fedora_base" 'vendor:claude-desktop'
assert_not_contains "$fedora_base" 'copr:dejan/lazygit'
assert_not_contains "$fedora_base" 'code'
assert_not_contains "$fedora_base" 'claude-desktop'
assert_not_contains "$fedora_base" 'lazygit'
assert_not_contains "$fedora_base" 'steam'
assert_not_contains "$fedora_base" 'com.discordapp.Discord'
assert_not_contains "$fedora_base" 'net.davidotek.pupgui2'
assert_not_contains "$fedora_base" 'org.onlyoffice.desktopeditors'
assert_not_contains "$fedora_base" 'com.github.IsmaelMartinez.teams_for_linux'
assert_not_contains "$fedora_base" 'us.zoom.Zoom'
assert_not_contains "$fedora_base" 'com.spotify.Client'
assert_not_contains "$fedora_base" 'brew:codex'
assert_not_contains "$fedora_base" 'brew:opencode'
assert_not_contains "$fedora_base" 'brew:lazydocker'
assert_not_contains "$fedora_base" 'claude-code'
assert_not_contains "$fedora_base" 'jetbrains-toolbox'
assert_not_contains "$fedora_base" 'devtunnel'
assert_not_contains "$fedora_base" 'docker-fedora'
assert_not_contains "$fedora_base" 'dotnet-sdk'
assert_not_contains "$fedora_base" 'dotnet-tools'
assert_not_contains "$fedora_base" 'media-codecs-fedora'
assert_contains "$fedora_base" 'ms-fonts-fedora'
assert_contains "$fedora_base" 'jetbrains-mono-nerd-font-fedora'
assert_not_contains "$fedora_base" 'build-tools-fedora'
assert_contains "$fedora_base" 'zsh'
assert_contains "$fedora_base" 'starship'
assert_contains "$fedora_base" 'zoxide'
assert_contains "$fedora_base" 'fastfetch'
assert_contains "$fedora_base" 'gh'
assert_contains "$fedora_base" 'btop'
assert_contains "$fedora_base" 'fd-find'
assert_contains "$fedora_base" 'fzf'
assert_contains "$fedora_base" 'bat'
assert_contains "$fedora_base" 'yazi'
assert_contains "$fedora_base" 'ImageMagick'
assert_contains "$fedora_base" 'mpv'
assert_contains "$fedora_base" 'pavucontrol'
assert_contains "$fedora_base" 'tesseract'
assert_contains "$fedora_base" 'tesseract-langpack-eng'
assert_contains "$fedora_base" 'cups'
assert_contains "$fedora_base" 'avahi-daemon'
assert_contains "$fedora_base" '~/.local/bin/zz'
assert_contains "$fedora_base" '~/.config/autostart/zz-first-run.desktop'
assert_contains "$fedora_base" 'Base rationale:'

fedora_helium="$(run_case fedora-helium print-plan --distro fedora --select browser=helium-copr --dry-run)"
assert_contains "$fedora_helium" 'copr:imput/helium'
assert_contains "$fedora_helium" 'helium-bin'

fedora_chrome="$(run_case fedora-chrome print-plan --distro fedora --select browser=chrome --dry-run)"
assert_contains "$fedora_chrome" 'vendor:google-chrome'
assert_contains "$fedora_chrome" 'google-chrome-stable'

fedora_brave="$(run_case fedora-brave print-plan --distro fedora --select browser=brave --dry-run)"
assert_contains "$fedora_brave" 'vendor:brave'
assert_contains "$fedora_brave" 'brave-browser'

fedora_dotnet_tools="$(run_case fedora-dotnet-tools print-plan --distro fedora --select dotnet=tools --dry-run)"
assert_contains "$fedora_dotnet_tools" 'dotnet-sdk'
assert_contains "$fedora_dotnet_tools" 'dotnet-tools'

fedora_dev="$(run_case fedora-dev print-plan --distro fedora --select dev=vscode,lazygit --select ai=codex --dry-run)"
assert_contains "$fedora_dev" 'vendor:vscode'
assert_contains "$fedora_dev" 'copr:dejan/lazygit'
assert_contains "$fedora_dev" 'code'
assert_contains "$fedora_dev" 'lazygit'
assert_contains "$fedora_dev" 'brew:codex'

fedora_install="$(run_install_case fedora-install --distro fedora)"
assert_contains "$fedora_install" '==> [1/9] Preflight'
assert_contains "$fedora_install" '==> [4/9] Base Setup'
assert_contains "$fedora_install" '==> [5/9] Optional Packages'
assert_contains "$fedora_install" '==> [6/9] Custom Actions'
assert_contains "$fedora_install" '==> [9/9] Doctor'
assert_not_contains "$fedora_install" 'sudo dnf group install -y development-tools'
assert_not_contains "$fedora_install" 'DRY-RUN: brew install codex'
assert_not_contains "$fedora_install" 'DRY-RUN: install active .NET SDK channels'
assert_contains "$fedora_install" 'DRY-RUN: install JetBrains Mono Nerd Font'
assert_contains "$fedora_install" 'sudo systemctl daemon-reload'
assert_contains "$fedora_install" 'sudo systemctl set-default graphical.target'
assert_contains "$fedora_install" 'sudo systemctl enable --force sddm.service'

printf 'planner ok\n'
