#!/usr/bin/env bash
set -Eeuo pipefail

module_70_user_services() {
  run_cmd_as_user "$TARGET_USER" systemctl --user daemon-reload || true
}

