#!/usr/bin/env bash
set -Eeuo pipefail

module_50_greetd() {
  [[ "$SKIP_GREETD" -eq 1 ]] && return 0
  file_template_if_changed "$ROOT_DIR/templates/greetd/config.toml" /etc/greetd/config.toml 0644
  run_cmd sudo systemctl set-default graphical.target
  if [[ "$DRY_RUN" -eq 1 ]]; then
    distro_enable_service "greetd"
  else
    service_enable_if_exists "greetd"
  fi
  printf 'greetd is enabled. Reboot to start the graphical login.\n'
}

