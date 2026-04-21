#!/usr/bin/env bash
set -Eeuo pipefail

module_40_services() {
  [[ "$SKIP_SERVICES" -eq 1 ]] && return 0
  local service_name
  while IFS= read -r service_name; do
    [[ -n "$service_name" ]] || continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
      distro_enable_service_now "$service_name"
    else
      systemctl_enable_now_if_exists "$service_name"
    fi
  done < <(system_services_now_from_plan)
}

