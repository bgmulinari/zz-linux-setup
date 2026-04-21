#!/usr/bin/env bash
set -Eeuo pipefail

module_60_dotfiles() {
  [[ "$SKIP_DOTFILES" -eq 1 ]] && return 0
  stow_apply_plan
}

