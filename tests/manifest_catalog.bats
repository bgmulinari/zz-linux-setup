#!/usr/bin/env bats

load "helpers/common"

setup() {
  setup_test_env
  source_core
}

teardown() {
  rm -rf "$ROOT_DIR/bundles/fedora/__test__" "$ROOT_DIR/packages/fedora/__test__"
}

@test "manifest parser trims comments, blanks, whitespace, and duplicates" {
  manifest="$TEST_ROOT/test.pkgs"
  printf '%s\n' \
    '# comment' \
    'ghostty' \
    '' \
    'firefox   # inline comment' \
    'ghostty' \
    '  chromium  ' \
    >"$manifest"

  assert_equal $'chromium\nfirefox\nghostty' "$(manifest_entries "$manifest")"
}

@test "distro detection recognizes Fedora os-release files" {
  os_release="$TEST_ROOT/fedora-os-release"
  printf 'ID=fedora\n' >"$os_release"

  assert_equal "fedora" "$(detect_distro_from_file "$os_release")"
}

@test "bundle descriptor validation rejects missing or unsupported fields" {
  mkdir -p "$ROOT_DIR/bundles/fedora/__test__" "$ROOT_DIR/packages/fedora/__test__"
  printf 'test-package\n' >"$ROOT_DIR/packages/fedora/__test__/valid.pkgs"

  cat >"$ROOT_DIR/bundles/fedora/__test__/valid.bundle" <<'EOF'
BUNDLE_ID="test-valid"
BUNDLE_INSTALLER="dnf"
BUNDLE_SOURCE_ID=""
BUNDLE_ITEMS_FILE="packages/fedora/__test__/valid.pkgs"
BUNDLE_STOW_PACKAGES=""
BUNDLE_DESCRIPTION="Valid test bundle"
EOF
  validate_bundle_descriptor fedora "$ROOT_DIR/bundles/fedora/__test__/valid.bundle"

  cat >"$ROOT_DIR/bundles/fedora/__test__/missing-id.bundle" <<'EOF'
BUNDLE_INSTALLER="dnf"
BUNDLE_SOURCE_ID=""
BUNDLE_ITEMS_FILE="packages/fedora/__test__/valid.pkgs"
BUNDLE_STOW_PACKAGES=""
BUNDLE_DESCRIPTION="Missing id"
EOF
  run validate_bundle_descriptor fedora "$ROOT_DIR/bundles/fedora/__test__/missing-id.bundle"
  [ "$status" -ne 0 ]

  cat >"$ROOT_DIR/bundles/fedora/__test__/bad-installer.bundle" <<'EOF'
BUNDLE_ID="test-bad-installer"
BUNDLE_INSTALLER="brew"
BUNDLE_SOURCE_ID=""
BUNDLE_ITEMS_FILE="packages/fedora/__test__/valid.pkgs"
BUNDLE_STOW_PACKAGES=""
BUNDLE_DESCRIPTION="Bad installer"
EOF
  run validate_bundle_descriptor fedora "$ROOT_DIR/bundles/fedora/__test__/bad-installer.bundle"
  [ "$status" -ne 0 ]

  cat >"$ROOT_DIR/bundles/fedora/__test__/missing-items.bundle" <<'EOF'
BUNDLE_ID="test-missing-items"
BUNDLE_INSTALLER="dnf"
BUNDLE_SOURCE_ID=""
BUNDLE_ITEMS_FILE="packages/fedora/__test__/missing.pkgs"
BUNDLE_STOW_PACKAGES=""
BUNDLE_DESCRIPTION="Missing items file"
EOF
  run validate_bundle_descriptor fedora "$ROOT_DIR/bundles/fedora/__test__/missing-items.bundle"
  [ "$status" -ne 0 ]
}

@test "source descriptors include required trust metadata" {
  local source_file
  while IFS= read -r source_file; do
    assert_file_contains "$source_file" 'SOURCE_GPG_POLICY='
    assert_file_contains "$source_file" 'SOURCE_BOOTSTRAP_EXCEPTION='
    assert_file_contains "$source_file" 'SOURCE_REQUIRED='
    assert_file_contains "$source_file" 'SOURCE_REASON='
  done < <(find "$ROOT_DIR/sources/fedora" -type f -name '*.source' | sort)

  assert_file_contains "$ROOT_DIR/sources/fedora/terra/terra.source" 'SOURCE_GPG_POLICY="unsigned-bootstrap"'
  assert_file_contains "$ROOT_DIR/sources/fedora/terra/terra.source" 'SOURCE_BOOTSTRAP_EXCEPTION=1'
}

@test "base bundle ids are not exposed as optional choice ids" {
  local base_id choice_file
  for base_id in "${BASE_BUNDLE_IDS_fedora[@]}"; do
    for choice_file in "$ROOT_DIR"/choices/fedora/*.conf; do
      ! awk -F'\t' -v id="$base_id" 'NF==5 && $1 == id {found=1} END {exit found ? 0 : 1}' "$choice_file"
    done
  done
}
