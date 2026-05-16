#!/usr/bin/env bash
set -Eeuo pipefail

append_managed_file() {
  local path="$1"
  append_plan_entries "$PLAN_DIR/files/managed-files.list" "$path"
}

append_managed_files_for_stow_package() {
  local package_name="$1"
  local package_dir="$ROOT_DIR/dotfiles/$package_name"
  [[ -d "$package_dir" ]] || return 0

  local relative_path
  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    append_managed_file "~/$relative_path"
  done < <(find "$package_dir" -type f ! -name '.keep' -printf '%P\n' | sort)
}

managed_files_report_path() {
  printf '%s/managed-files-report.txt\n' "$STATE_DIR"
}

write_managed_files_report() {
  ensure_state_dirs
  local report_file
  report_file="$(managed_files_report_path)"
  {
    printf 'Managed files report\n'
    printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Target user: %s\n' "${TARGET_USER:-}"
    printf 'Target home: %s\n' "${TARGET_HOME:-}"

    printf '\nPlanned managed files:\n'
    if [[ -f "$PLAN_DIR/files/managed-files.list" ]]; then
      sed 's/^/  - /' "$PLAN_DIR/files/managed-files.list"
    fi

    printf '\nPlanned backup-before-stow conflicts:\n'
    if [[ -f "$PLAN_DIR/files/config-conflicts.tsv" ]]; then
      awk -F'\t' 'NF>=3 {printf "  - %s (%s: %s)\n", $1, $2, $3}' "$PLAN_DIR/files/config-conflicts.tsv"
    fi

    printf '\nExisting backups:\n'
    if [[ -d "$STATE_DIR/backups" ]]; then
      find "$STATE_DIR/backups" -mindepth 1 -type f -o -type l 2>/dev/null | sort | sed 's/^/  - /'
    fi
  } >"$report_file"
}
