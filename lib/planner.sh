#!/usr/bin/env bash
set -Eeuo pipefail

plan_reset() {
  rm -rf "$PLAN_DIR"
  mkdir -p \
    "$PLAN_DIR/sources" \
    "$PLAN_DIR/packages" \
    "$PLAN_DIR/flatpak" \
    "$PLAN_DIR/services" \
    "$PLAN_DIR/files" \
    "$PLAN_DIR/stow"
  : >"$PLAN_DIR/summary.txt"
}

append_warning() {
  append_unique WARNING_MESSAGES "$1"
}

append_info() {
  append_unique INFO_MESSAGES "$1"
}

add_source_to_plan() {
  local source_id="$1"
  append_unique ENABLED_SOURCES "$source_id"
}

add_manifest_to_plan() {
  local manifest_path="$1"
  local kind
  kind="$(manifest_kind_from_path "$manifest_path")"
  local destination
  destination="$(package_file_for_kind "$kind")"
  mapfile -t manifest_items < <(manifest_entries "$ROOT_DIR/$manifest_path")
  append_plan_entries "$destination" "${manifest_items[@]:-}"
}

effective_sources() {
  local -a all_sources=()
  local source_id
  case "$DISTRO" in
    fedora)
      for source_id in "${BASE_SOURCES_fedora[@]}"; do
        append_unique all_sources "$source_id"
      done
      ;;
    arch)
      for source_id in "${BASE_SOURCES_arch[@]}"; do
        append_unique all_sources "$source_id"
      done
      ;;
  esac

  for source_id in "${ENABLED_SOURCES[@]:-}"; do
    append_unique all_sources "$source_id"
  done
  for source_id in "${EXPLICIT_ENABLED_SOURCES[@]:-}"; do
    append_unique all_sources "$source_id"
  done
  printf '%s\n' "${all_sources[@]:-}"
}

build_plan_from_selections() {
  ensure_state_dirs
  plan_reset

  local -a manifest_paths=()
  local manifest_path
  case "$DISTRO" in
    fedora)
      for manifest_path in "${BASE_PACKAGE_MANIFESTS_fedora[@]}"; do
        append_unique manifest_paths "$manifest_path"
      done
      ;;
    arch)
      for manifest_path in "${BASE_PACKAGE_MANIFESTS_arch[@]}"; do
        append_unique manifest_paths "$manifest_path"
      done
      ;;
  esac

  local category choice_id record choice_sources choice_manifests
  for category in $(category_names "$DISTRO"); do
    validate_choice_catalog "$DISTRO" "$category"
    while IFS= read -r choice_id; do
      [[ -n "$choice_id" ]] || continue
      record="$(choice_record "$DISTRO" "$category" "$choice_id")"
      [[ -n "$record" ]] || die "Unknown choice '$choice_id' in category '$category'"
      choice_sources="$(choice_field "$record" 4)"
      choice_manifests="$(choice_field "$record" 5)"
      while IFS= read -r item; do
        [[ -n "$item" ]] && append_unique ENABLED_SOURCES "$item"
      done < <(split_csv "$choice_sources")
      while IFS= read -r item; do
        [[ -n "$item" ]] && append_unique manifest_paths "$item"
      done < <(split_csv "$choice_manifests")

      if [[ "$category" == "media" && "$choice_id" == "codecs" ]]; then
        CODECS_SELECTED=1
      fi
      if [[ "$DISTRO" == "arch" && "$category" == "gaming" && "$choice_id" == "steam" && "$MULTILIB_CONFIRMED" -ne 1 ]]; then
        append_warning "Steam may require Arch multilib. Re-run with --enable-source multilib or confirm in the wizard."
      fi
    done < <(effective_choice_ids "$DISTRO" "$category")
  done

  if array_contains "copr:scottames/ghostty" "${ENABLED_SOURCES[@]:-}" "${EXPLICIT_ENABLED_SOURCES[@]:-}"; then
    remove_value manifest_paths "packages/fedora/terra/ghostty.pkgs"
    append_unique manifest_paths "packages/fedora/copr/scottames-ghostty/terminal.pkgs"
  fi

  if grep -Rqs 'packages/.*/flatpak/' "$ROOT_DIR/choices/$DISTRO"; then
    :
  fi

  local wants_flatpak=0
  for manifest_path in "${manifest_paths[@]:-}"; do
    if [[ "$manifest_path" == *"/flatpak/"* || "$manifest_path" == packages/*/flatpak/*.flatpaks ]]; then
      wants_flatpak=1
      break
    fi
  done
  if array_contains "flathub" "${ENABLED_SOURCES[@]:-}" "${EXPLICIT_ENABLED_SOURCES[@]:-}"; then
    wants_flatpak=1
  fi
  if [[ "$wants_flatpak" -eq 1 ]]; then
    append_unique ENABLED_SOURCES "flathub"
    append_unique manifest_paths "packages/$DISTRO/official/flatpak.pkgs"
  fi

  if [[ "$DISTRO" == "fedora" ]]; then
    if array_contains "rpmfusion-free" "${ENABLED_SOURCES[@]:-}" || array_contains "rpmfusion-nonfree" "${ENABLED_SOURCES[@]:-}"; then
      :
    fi
  fi

  local source_id
  while IFS= read -r source_id; do
    [[ -n "$source_id" ]] || continue
    append_plan_source "$source_id"
  done < <(effective_sources)

  for manifest_path in "${manifest_paths[@]:-}"; do
    add_manifest_to_plan "$manifest_path"
  done

  append_plan_entries "$PLAN_DIR/services/system-enable-now.list" "${DEFAULT_SYSTEM_SERVICES[@]}"
  append_plan_entries "$PLAN_DIR/services/system-enable.list" "greetd"
  : >"$PLAN_DIR/services/user-enable.list"

  if array_contains "libvirt" $(effective_choice_ids "$DISTRO" "virtualization"); then
    append_plan_entries "$PLAN_DIR/services/system-enable-now.list" "libvirtd"
  fi
  if array_contains "base" $(effective_choice_ids "$DISTRO" "print-scan"); then
    append_plan_entries "$PLAN_DIR/services/system-enable-now.list" "cups"
  fi

  append_plan_entries "$PLAN_DIR/stow/packages.list" "${DEFAULT_STOW_PLAN[@]}"
  append_managed_file "~/.config/niri/config.kdl"
  append_managed_file "~/.config/xdg-desktop-portal/niri-portals.conf"
  append_managed_file "~/.config/environment.d/10-niri-kde-qt.conf"
  append_managed_file "~/.config/ghostty/config"
  append_managed_file "~/.config/fuzzel/fuzzel.ini"
  append_managed_file "~/.config/qt6ct/qt6ct.conf"
  append_managed_file "~/.config/kdeglobals"
  append_managed_file "/etc/greetd/config.toml"

  write_plan_summary
  save_selections
}

count_plan_entries() {
  local file="$1"
  [[ -f "$file" ]] || {
    printf '0\n'
    return 0
  }
  wc -l <"$file" | tr -d ' '
}

write_plan_summary() {
  {
    printf 'Distro: %s\n' "$DISTRO"
    printf 'Target user: %s\n' "$TARGET_USER"
    printf '\nSources:\n'
    local source_list
    for source_list in "$PLAN_DIR"/sources/*.list; do
      [[ -f "$source_list" ]] || continue
      printf '  %s (%s)\n' "$(basename "$source_list")" "$(count_plan_entries "$source_list")"
      sed 's/^/    - /' "$source_list" 2>/dev/null || true
    done
    printf '\nPackages:\n'
    local package_list
    for package_list in "$PLAN_DIR"/packages/*.pkgs; do
      [[ -f "$package_list" ]] || continue
      printf '  %s (%s)\n' "$(basename "$package_list")" "$(count_plan_entries "$package_list")"
      sed 's/^/    - /' "$package_list" 2>/dev/null || true
    done
    printf '\nFlatpaks:\n'
    if [[ -f "$PLAN_DIR/flatpak/apps.flatpaks" ]]; then
      sed 's/^/  - /' "$PLAN_DIR/flatpak/apps.flatpaks"
    fi
    printf '\nServices:\n'
    if [[ -f "$PLAN_DIR/services/system-enable-now.list" ]]; then
      sed 's/^/  - /' "$PLAN_DIR/services/system-enable-now.list"
    fi
    printf '\nFiles:\n'
    if [[ -f "$PLAN_DIR/files/managed-files.list" ]]; then
      sed 's/^/  - /' "$PLAN_DIR/files/managed-files.list"
    fi
    printf '\nStow:\n'
    if [[ -f "$PLAN_DIR/stow/packages.list" ]]; then
      sed 's/^/  - /' "$PLAN_DIR/stow/packages.list"
    fi
    if [[ "${#WARNING_MESSAGES[@]}" -gt 0 ]]; then
      printf '\nWarnings:\n'
      printf '  - %s\n' "${WARNING_MESSAGES[@]}"
    fi
  } >"$PLAN_DIR/summary.txt"
}

print_plan_summary() {
  [[ -f "$PLAN_DIR/summary.txt" ]] || die "No generated plan found."
  cat "$PLAN_DIR/summary.txt"
}
