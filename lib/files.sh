#!/usr/bin/env bash
set -Eeuo pipefail

append_managed_file() {
  local path="$1"
  append_plan_entries "$PLAN_DIR/files/managed-files.list" "$path"
}

