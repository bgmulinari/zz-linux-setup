#!/usr/bin/env bash
set -Eeuo pipefail

# .NET SDK channel and dotnet-tool:<package> global tool custom actions. The
# install-script pins and channel-selection algorithm are shared with
# `zz update` via lib/dotnet.sh.

install_dotnet_sdks() {
  local install_dir="$TARGET_HOME/$DOTNET_INSTALL_DIR_NAME"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'DRY-RUN: install supported .NET SDK channels -> %s\n' "$install_dir"
    return 0
  fi

  local metadata install_script channel failed=0
  log_progress "Downloading .NET release metadata and installer"
  metadata="$(mktemp "$CACHE_DIR/dotnet-releases.XXXXXX")"
  install_script="$(mktemp "$CACHE_DIR/dotnet-install.XXXXXX")"
  if ! run_cmd curl -fsSL "$DOTNET_RELEASES_INDEX_URL" -o "$metadata" \
    || ! run_cmd curl -fsSL "$DOTNET_INSTALL_SCRIPT_URL" -o "$install_script" \
    || ! printf '%s  %s\n' "$DOTNET_INSTALL_SHA256" "$install_script" | sha256sum -c -; then
    rm -f "$metadata" "$install_script"
    return 1
  fi
  run_cmd chmod 0755 "$install_script"

  local -a channels=()
  while IFS= read -r channel; do
    [[ -n "$channel" ]] && channels+=("$channel")
  done < <(dotnet_selected_channels "$metadata" || true)

  if [[ "${#channels[@]}" -eq 0 ]]; then
    rm -f "$metadata" "$install_script"
    log_warn "No supported .NET SDK channels were found in Microsoft release metadata."
    return 1
  fi

  log_info "Installing .NET SDK channels: $(join_by ', ' "${channels[@]}")"
  for channel in "${channels[@]}"; do
    log_progress "Installing .NET SDK channel: $channel"
    if ! run_cmd_as_user "$TARGET_USER" bash "$install_script" --channel "$channel" --install-dir "$install_dir"; then
      failed=1
      log_warn "Failed to install .NET SDK channel: $channel"
    fi
  done
  rm -f "$metadata" "$install_script"

  if [[ ! -x "$install_dir/dotnet" ]]; then
    log_warn ".NET SDK installer completed without creating $install_dir/dotnet."
    return 1
  fi
  [[ "$failed" -eq 0 ]]
}

verify_dotnet_sdk() {
  [[ -x "$TARGET_HOME/$DOTNET_INSTALL_DIR_NAME/dotnet" ]]
}

dotnet_user_bin() {
  printf '%s/%s/dotnet\n' "$TARGET_HOME" "$DOTNET_INSTALL_DIR_NAME"
}

# Print the installed global tool package IDs, one per line and lowercased:
# `dotnet tool list -g` prints a two-line header and then the package ID,
# version, and command columns.
dotnet_installed_tools() {
  local dotnet_bin
  dotnet_bin="$(dotnet_user_bin)"
  [[ -x "$dotnet_bin" ]] || return 0
  run_cmd_as_user "$TARGET_USER" "$dotnet_bin" tool list -g 2>/dev/null \
    | awk 'NR > 2 && $1 != "" {print tolower($1)}' || true
}

install_dotnet_tool() {
  local package="$1" dotnet_bin
  dotnet_bin="$(dotnet_user_bin)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'DRY-RUN: install .NET global tool: %s\n' "$package"
    return 0
  fi

  if [[ ! -x "$dotnet_bin" ]]; then
    log_warn ".NET SDK is not available at $dotnet_bin; running SDK install before installing tools."
    install_dotnet_sdks
  fi
  if [[ ! -x "$dotnet_bin" ]]; then
    log_warn ".NET SDK is still not available at $dotnet_bin; cannot install .NET global tool $package."
    return 1
  fi

  log_progress "Installing .NET global tool: $package"
  run_cmd_as_user "$TARGET_USER" "$dotnet_bin" tool update -g "$package" \
    || run_cmd_as_user "$TARGET_USER" "$dotnet_bin" tool install -g "$package"
}

verify_dotnet_tool() {
  local package="$1"
  [[ -x "$(dotnet_user_bin)" ]] || return 1
  dotnet_installed_tools | grep -Fxq "${package,,}"
}

remove_dotnet_tool() {
  local package="$1" dotnet_bin
  dotnet_bin="$(dotnet_user_bin)"
  if [[ ! -x "$dotnet_bin" ]]; then
    log_info "No .NET SDK at $dotnet_bin; nothing to uninstall for $package"
    return 0
  fi
  log_progress "Removing .NET global tool: $package"
  run_cmd_as_user "$TARGET_USER" "$dotnet_bin" tool uninstall -g "$package"
}

register_action "dotnet-sdk" install_dotnet_sdks verify_dotnet_sdk
register_action "dotnet-tool" install_dotnet_tool verify_dotnet_tool
