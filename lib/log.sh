#!/usr/bin/env bash
set -Eeuo pipefail

log_ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_info() {
  printf '[%s] INFO  %s\n' "$(log_ts)" "$*" >&2
}

log_warn() {
  printf '[%s] WARN  %s\n' "$(log_ts)" "$*" >&2
}

log_error() {
  printf '[%s] ERROR %s\n' "$(log_ts)" "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

