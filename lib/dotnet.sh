#!/usr/bin/env bash
set -Eeuo pipefail

# Shared .NET SDK contract: the pinned dotnet-install script revision and the
# supported-channel selection algorithm. Both the installer custom action
# (lib/actions/dotnet.sh) and the post-install updater (bin/zz.d/update)
# source this file so install and update behavior cannot drift.

# shellcheck disable=SC2034  # Consumed by lib/actions/dotnet.sh and bin/zz.d/update.
DOTNET_INSTALL_DIR_NAME=".dotnet"
DOTNET_INSTALL_COMMIT="4a37a9f9d1a061fc389d6515100336db4e51710e"
# shellcheck disable=SC2034  # Consumed by lib/actions/dotnet.sh and bin/zz.d/update.
DOTNET_INSTALL_SHA256="082f7685e156738a1b2e2ed8381a621870d4ce8e8c59278034556f05c186eb2e"
# shellcheck disable=SC2034  # Consumed by lib/actions/dotnet.sh and bin/zz.d/update.
DOTNET_RELEASES_INDEX_URL="https://dotnetcli.azureedge.net/dotnet/release-metadata/releases-index.json"
# shellcheck disable=SC2034  # Consumed by lib/actions/dotnet.sh and bin/zz.d/update.
DOTNET_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/dotnet/install-scripts/$DOTNET_INSTALL_COMMIT/src/dotnet-install.sh"

# Print the channel versions to install, newest first: every channel whose
# support phase Microsoft has not marked eol. Preview and go-live channels
# count too, so a release candidate installs alongside the shipped SDKs and
# a channel drops out only once it reaches end of life.
dotnet_selected_channels() {
  local metadata_file="$1" channels
  channels="$(jq -r '
    .["releases-index"][]
    | select(.["support-phase"] != "eol")
    | .["channel-version"]
  ' "$metadata_file" | sort -Vr)"
  [[ -n "$channels" ]] || return 1
  printf '%s\n' "$channels"
}
