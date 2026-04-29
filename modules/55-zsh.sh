#!/usr/bin/env bash
set -Eeuo pipefail

zsh_plan_has_package() {
  local package_name="$1"
  local plan_file
  for plan_file in "$PLAN_DIR"/packages/*.pkgs; do
    [[ -f "$plan_file" ]] || continue
    if grep -Fx "$package_name" "$plan_file" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

module_55_zsh() {
  zsh_plan_has_package "zsh" || return 0

  local shell_path="/bin/zsh"
  local oh_my_zsh_dir="$TARGET_HOME/.oh-my-zsh"
  local custom_plugins_dir="$oh_my_zsh_dir/custom/plugins"
  local zshrc_path="$TARGET_HOME/.zshrc"

  if [[ "$DRY_RUN" -eq 0 ]] && ! command -v zsh >/dev/null 2>&1; then
    log_warn "zsh was planned but not found after package install; retrying direct install."
    case "$DISTRO" in
      fedora) package_install_idempotent dnf zsh ;;
      arch) package_install_idempotent pacman zsh ;;
      *) die "Unsupported distro for zsh remediation: $DISTRO" ;;
    esac
    command -v zsh >/dev/null 2>&1 || die "zsh is mandatory but could not be installed. Check package manager output above."
  fi

  if [[ ! -d "$oh_my_zsh_dir" ]]; then
    run_cmd_as_user "$TARGET_USER" bash -lc 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
  fi

  run_cmd_as_user "$TARGET_USER" mkdir -p "$custom_plugins_dir"
  run_cmd_as_user "$TARGET_USER" mkdir -p "$TARGET_HOME/.zsh" "$TARGET_HOME/.zshrc.d"

  if [[ ! -d "$custom_plugins_dir/zsh-autosuggestions" ]]; then
    run_cmd_as_user "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$custom_plugins_dir/zsh-autosuggestions"
  fi

  if [[ ! -d "$custom_plugins_dir/zsh-syntax-highlighting" ]]; then
    run_cmd_as_user "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom_plugins_dir/zsh-syntax-highlighting"
  fi

  if ! grep -qxF "$shell_path" /etc/shells 2>/dev/null; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf 'DRY-RUN: append %s to /etc/shells\n' "$shell_path"
    else
      run_cmd_as_root sh -c 'printf "%s\n" "$1" >> /etc/shells' sh "$shell_path"
    fi
  fi

  if [[ -f "$zshrc_path" && ! -L "$zshrc_path" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf 'DRY-RUN: rm -f %s\n' "$zshrc_path"
    else
      run_cmd_as_user "$TARGET_USER" rm -f "$zshrc_path"
    fi
  fi

  local current_shell=""
  current_shell="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7 || true)"
  if [[ -z "$current_shell" ]]; then
    die "Could not resolve current login shell for target user '$TARGET_USER'."
  fi
  if [[ "$current_shell" != "$shell_path" ]]; then
    run_cmd_as_root chsh -s "$shell_path" "$TARGET_USER"
  fi
}
