#!/usr/bin/env bash
set -Eeuo pipefail

module_20_should_render_readiness_report() {
  [[ "$COMMAND" == "wizard" && "$ASSUME_YES" -ne 1 ]] && return 1
  return 0
}

module_20_plan() {
  generate_readiness_status
  tui_show_install_plan
  if module_20_should_render_readiness_report; then
    printf '\n'
    render_readiness_report
  fi
  if [[ "$COMMAND" == "wizard" && "$ASSUME_YES" -ne 1 ]]; then
    printf '\n'
    if ! tui_confirm "Proceed with this install plan?"; then
      printf 'Install cancelled.\n'
      exit 0
    fi
  fi
}
