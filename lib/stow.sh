#!/usr/bin/env bash
set -Eeuo pipefail

stow_packages_from_plan() {
  read_plan_file "$PLAN_DIR/stow/packages.list"
}

stow_apply_plan() {
  [[ "$SKIP_DOTFILES" -eq 1 ]] && return 0
  local -a packages=()
  while IFS= read -r package_name; do
    [[ -n "$package_name" ]] && packages+=("$package_name")
  done < <(stow_packages_from_plan)
  [[ "${#packages[@]}" -gt 0 ]] || return 0

  local -a simulate_cmd=(
    stow
    --dir "$ROOT_DIR/dotfiles"
    --target "$TARGET_HOME"
    --simulate
    --verbose=2
  )
  local -a apply_cmd=(
    stow
    --dir "$ROOT_DIR/dotfiles"
    --target "$TARGET_HOME"
    --restow
  )
  if [[ "$STOW_ADOPT" -eq 1 ]]; then
    apply_cmd+=(--adopt)
  fi
  simulate_cmd+=("${packages[@]}")
  apply_cmd+=("${packages[@]}")

  if [[ "$DRY_RUN" -eq 1 ]]; then
    run_cmd_as_user "$TARGET_USER" "${simulate_cmd[@]}"
    run_cmd_as_user "$TARGET_USER" "${apply_cmd[@]}"
    return 0
  fi

  local output_file
  output_file="$(mktemp "$CACHE_DIR/stow-simulate.XXXXXX")"
  if ! sudo -u "$TARGET_USER" "${simulate_cmd[@]}" >"$output_file" 2>&1; then
    cat "$output_file" >&2
    rm -f "$output_file"
    die "Stow reported conflicts. Re-run with --stow-adopt only if you intentionally want to adopt existing files."
  fi
  rm -f "$output_file"
  run_cmd_as_user "$TARGET_USER" "${apply_cmd[@]}"
}

