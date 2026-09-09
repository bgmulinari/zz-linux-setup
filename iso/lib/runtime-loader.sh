#!/usr/bin/env bash
# Remote runtime loader executed inside Anaconda by the ZZ Fedora add-on
# (iso/anaconda-addon/org_zz_fedora/runtime.py). It refreshes the repository
# snapshot used by the ISO install and is not part of the install.sh path.
#
# The snapshot is resolved in two plain HTTPS requests against the repository
# host, without the GitHub REST API and its unauthenticated rate limit: the git
# ref advertisement names the commit the ref points at, and the archive
# endpoint returns that exact commit as a tarball whose top-level directory
# ends with the commit id.
set -Eeuo pipefail

ISO_RUNTIME_REPOSITORY_URL="${ZZ_ISO_RUNTIME_REPOSITORY_URL:-https://github.com/bgmulinari/zz-fedora}"
ISO_RUNTIME_REPOSITORY_URL="${ISO_RUNTIME_REPOSITORY_URL%/}"
ISO_RUNTIME_REPOSITORY_URL="${ISO_RUNTIME_REPOSITORY_URL%.git}"
ISO_RUNTIME_REF="${ZZ_ISO_RUNTIME_REF:-main}"
ISO_RUNTIME_DIR="${ZZ_ISO_RUNTIME_DIR:-/run/zz-fedora/repository}"
ISO_RUNTIME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ISO_RUNTIME_PATHS_FILE="${ZZ_ISO_RUNTIME_PATHS_FILE:-$ISO_RUNTIME_ROOT/iso/payload-paths.conf}"
ISO_RUNTIME_REFS_URL="$ISO_RUNTIME_REPOSITORY_URL/info/refs?service=git-upload-pack"

iso_runtime_err() {
  printf 'zz-fedora-runtime: %s\n' "$*" >&2
}

iso_runtime_path_is_safe() {
  local runtime_path="$1"
  [[ -n "$runtime_path" && "$runtime_path" != /* ]] || return 1
  [[ "$runtime_path" != "." && "$runtime_path" != ".." ]] || return 1
  [[ "$runtime_path" != ../* && "$runtime_path" != */../* && "$runtime_path" != */.. ]]
}

iso_runtime_repository_origin() {
  local url="$ISO_RUNTIME_REPOSITORY_URL" rest
  case "$url" in
    http://*|https://*) ;;
    *) return 1 ;;
  esac
  rest="${url#*://}"
  printf '%s://%s/\n' "${url%%://*}" "${rest%%/*}"
}

# Fail within seconds when the repository host cannot be reached at all,
# instead of letting the fetches spend their retries on a network that silently
# drops every connection. Anything past the connection itself (TLS, HTTP status)
# is left to the fetches, which own clock recovery.
iso_probe_runtime_origin() {
  local origin probe_status
  origin="$(iso_runtime_repository_origin)" || return 0
  if curl \
    --head \
    --silent \
    --show-error \
    --connect-timeout 5 \
    --max-time 15 \
    --header 'User-Agent: zz-fedora-installer' \
    --output /dev/null \
    "$origin"; then
    return 0
  else
    probe_status=$?
  fi

  case "$probe_status" in
    5|6)
      iso_runtime_err "cannot resolve $origin: check the network connection or the installation source proxy"
      ;;
    7|28)
      iso_runtime_err "cannot connect to $origin: check the network connection or the installation source proxy"
      ;;
    *)
      return 0
      ;;
  esac
  return 1
}

# iso_runtime_fetch DESTINATION URL MAX_TIME
iso_runtime_fetch() {
  local destination="$1" url="$2" max_time="$3"
  curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --retry 5 \
    --connect-timeout 15 \
    --max-time "$max_time" \
    --header 'User-Agent: zz-fedora-installer' \
    --output "$destination" \
    "$url"
}

iso_sync_installer_clock() {
  if command -v chronyc >/dev/null 2>&1 && chronyc tracking >/dev/null 2>&1; then
    chronyc waitsync 30 0 0 1
    return
  fi
  chronyd -q -t 30
}

# A fresh installer clock can predate the server certificate; curl reports that
# as exit 60. Synchronize once and repeat the same fetch.
iso_runtime_fetch_with_clock_recovery() {
  local fetch_status
  if iso_runtime_fetch "$@"; then
    return 0
  else
    fetch_status=$?
  fi

  if [[ "$fetch_status" -ne 60 ]] || ! command -v chronyd >/dev/null 2>&1; then
    return "$fetch_status"
  fi

  iso_runtime_err "TLS validation failed; synchronizing the installer clock"
  if ! iso_sync_installer_clock; then
    iso_runtime_err "could not synchronize the installer clock"
    return "$fetch_status"
  fi
  iso_runtime_fetch "$@"
}

# Print the commit id the runtime ref points at, read from the git smart-HTTP
# ref advertisement. Branches win over tags; an annotated tag resolves to the
# commit it tags (its peeled entry) when the server advertises one.
iso_resolve_runtime_revision() {
  local refs_file="$1" ref_pattern advertised revision=""
  ref_pattern="$(printf '%s' "$ISO_RUNTIME_REF" | sed -e 's/[][\.*^$+?(){}|]/\\&/g')"
  advertised="$(tr -d '\0' <"$refs_file")"
  local candidate
  for candidate in \
    "refs/heads/$ref_pattern" \
    "refs/tags/$ref_pattern\\^\\{\\}" \
    "refs/tags/$ref_pattern"; do
    revision="$(printf '%s\n' "$advertised" \
      | grep -oE "[0-9a-f]{40} $candidate\$" \
      | head -n 1 \
      | cut -c1-40)" || true
    [[ -z "$revision" ]] || break
  done
  [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || {
    iso_runtime_err "$ISO_RUNTIME_REPOSITORY_URL does not advertise ref $ISO_RUNTIME_REF"
    return 1
  }
  printf '%s\n' "$revision"
}

iso_refresh_runtime() (
  local command
  for command in cp curl tar; do
    command -v "$command" >/dev/null 2>&1 || {
      iso_runtime_err "missing required command: $command"
      return 1
    }
  done

  local destination_parent work_dir archive_dir staged_dir archive_file refs_file
  destination_parent="$(dirname "$ISO_RUNTIME_DIR")"
  mkdir -p "$destination_parent"
  work_dir="$(mktemp -d "$destination_parent/.repository-refresh.XXXXXX")"
  archive_dir="$work_dir/archive"
  staged_dir="$work_dir/repository"
  archive_file="$work_dir/repository.tar.gz"
  refs_file="$work_dir/refs"
  trap 'rm -rf "$work_dir"' EXIT

  mkdir -p "$archive_dir" "$staged_dir"
  iso_probe_runtime_origin

  local revision
  iso_runtime_err "resolving $ISO_RUNTIME_REF"
  iso_runtime_fetch_with_clock_recovery "$refs_file" "$ISO_RUNTIME_REFS_URL" 60
  revision="$(iso_resolve_runtime_revision "$refs_file")"

  iso_runtime_err "fetching $ISO_RUNTIME_REF at $revision"
  iso_runtime_fetch_with_clock_recovery \
    "$archive_file" \
    "$ISO_RUNTIME_REPOSITORY_URL/archive/$revision.tar.gz" \
    300

  local archive_root
  archive_root="$(tar -tzf "$archive_file" | sed -n '1{s:/$::;p;}')"
  [[ -n "$archive_root" && "$archive_root" != */* ]] || {
    iso_runtime_err "remote archive does not have one top-level directory"
    return 1
  }
  [[ "$archive_root" == *"-$revision" ]] || {
    iso_runtime_err "remote archive $archive_root does not match revision $revision"
    return 1
  }

  tar -xzf "$archive_file" \
    --no-same-owner \
    --strip-components=1 \
    -C "$archive_dir"

  local runtime_paths_file="$archive_dir/iso/payload-paths.conf"
  if [[ ! -f "$runtime_paths_file" ]]; then
    runtime_paths_file="$ISO_RUNTIME_PATHS_FILE"
    iso_runtime_err "remote runtime has no paths manifest; using embedded fallback"
  fi
  [[ -f "$runtime_paths_file" ]] || {
    iso_runtime_err "missing ISO payload paths manifest: $runtime_paths_file"
    return 1
  }
  local -a runtime_paths=()
  mapfile -t runtime_paths < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$runtime_paths_file")
  [[ "${#runtime_paths[@]}" -gt 0 ]] || {
    iso_runtime_err "ISO payload paths manifest is empty: $runtime_paths_file"
    return 1
  }
  local runtime_path staged_parent
  for runtime_path in "${runtime_paths[@]}"; do
    iso_runtime_path_is_safe "$runtime_path" || {
      iso_runtime_err "invalid ISO runtime path: $runtime_path"
      return 1
    }
    [[ -e "$archive_dir/$runtime_path" || -L "$archive_dir/$runtime_path" ]] || continue
    staged_parent="$staged_dir/$(dirname "$runtime_path")"
    mkdir -p "$staged_parent"
    cp -a "$archive_dir/$runtime_path" "$staged_parent/"
  done

  [[ -x "$staged_dir/install.sh" ]] || {
    iso_runtime_err "remote runtime is missing executable install.sh"
    return 1
  }
  [[ -d "$staged_dir/catalog/units" ]] || {
    iso_runtime_err "remote runtime is missing catalog/units"
    return 1
  }
  [[ -f "$staged_dir/lib/catalog.py" ]] || {
    iso_runtime_err "remote runtime is missing lib/catalog.py"
    return 1
  }

  mkdir -p "$staged_dir/config"
  {
    printf 'format=1\n'
    printf 'git_revision=%s\n' "$revision"
    printf 'worktree_changes=0\n'
    printf 'remote_ref=%s\n' "$ISO_RUNTIME_REF"
  } >"$staged_dir/config/iso-payload.conf"
  chmod 0644 "$staged_dir/config/iso-payload.conf"

  rm -rf "$ISO_RUNTIME_DIR"
  mv "$staged_dir" "$ISO_RUNTIME_DIR"
  iso_runtime_err "staged $ISO_RUNTIME_REF revision $revision"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  iso_refresh_runtime
fi
