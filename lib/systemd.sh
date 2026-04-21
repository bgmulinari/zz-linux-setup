#!/usr/bin/env bash
set -Eeuo pipefail

system_services_now_from_plan() {
  read_plan_file "$PLAN_DIR/services/system-enable-now.list"
}

system_services_from_plan() {
  read_plan_file "$PLAN_DIR/services/system-enable.list"
}

user_services_from_plan() {
  read_plan_file "$PLAN_DIR/services/user-enable.list"
}

