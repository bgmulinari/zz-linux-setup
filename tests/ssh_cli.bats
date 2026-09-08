#!/usr/bin/env bats

load "helpers/common"

setup() {
  setup_test_env
  setup_fake_bin
  export COMMAND_LOG
  export ZZ_SSH_HOME="$TARGET_HOME"
  export ZZ_SSH_SSHD_CONFIG_DIR="$TEST_ROOT/sshd_config.d"
  export ZZ_SSH_GITHUB_URL="https://github.example"
  export FAKE_STATE="$TEST_ROOT/fake-state"
  export ZZ_NO_TUI=0
  mkdir -p "$TARGET_HOME" "$FAKE_STATE"
  ssh-keygen -q -t ed25519 -N '' -C 'first@test' -f "$TEST_ROOT/first" >/dev/null
  ssh-keygen -q -t ed25519 -N '' -C 'second@test' -f "$TEST_ROOT/second" >/dev/null
  FIRST_KEY="$(cat "$TEST_ROOT/first.pub")"
  SECOND_KEY="$(cat "$TEST_ROOT/second.pub")"
  FIRST_MATERIAL="$(awk '{ print $1, $2 }' "$TEST_ROOT/first.pub")"
  SECOND_MATERIAL="$(awk '{ print $1, $2 }' "$TEST_ROOT/second.pub")"
  FIRST_FINGERPRINT="$(ssh-keygen -lf "$TEST_ROOT/first.pub" | awk '{ print $2 }')"
  SECOND_FINGERPRINT="$(ssh-keygen -lf "$TEST_ROOT/second.pub" | awk '{ print $2 }')"
  write_fakes
}

# sudo runs the command itself; systemctl keeps enabled/active state in files;
# sshd -T reflects whether the hardening drop-in exists, the way the real
# daemon's effective configuration would.
write_fakes() {
  write_fake_command sudo <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'sudo %s\n' "$*" >>"$COMMAND_LOG"
exec "$@"
EOF
  write_fake_command systemctl <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'systemctl %s\n' "$*" >>"$COMMAND_LOG"
args=("$@")
unit="${args[-1]}"
case "$1" in
  is-enabled) [[ -f "$FAKE_STATE/$unit.enabled" ]] ;;
  is-active) [[ -f "$FAKE_STATE/$unit.active" ]] ;;
  enable)
    touch "$FAKE_STATE/$unit.enabled"
    [[ "$2" != "--now" ]] || touch "$FAKE_STATE/$unit.active"
    ;;
  disable)
    rm -f "$FAKE_STATE/$unit.enabled"
    [[ "$2" != "--now" ]] || rm -f "$FAKE_STATE/$unit.active"
    ;;
  reload) [[ -f "$FAKE_STATE/$unit.active" ]] ;;
esac
EOF
  write_fake_command sshd <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'sshd %s\n' "$*" >>"$COMMAND_LOG"
case "$1" in
  -t) exit "${FAKE_SSHD_REJECT_CONFIG:-0}" ;;
  -T)
    printf 'port 22\n'
    if [[ -f "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" && "${FAKE_SSHD_IGNORE_DROPIN:-0}" -eq 0 ]]; then
      printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n'
    else
      printf 'PasswordAuthentication yes\nKbdInteractiveAuthentication yes\n'
    fi
    ;;
esac
EOF
  write_fake_command curl <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'curl %s\n' "$*" >>"$COMMAND_LOG"
[[ "${FAKE_CURL_FAIL:-0}" -eq 0 ]] || exit 22
cat "$FAKE_STATE/github.keys"
EOF
  write_fake_command gum <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'gum %s\n' "$*" >>"$COMMAND_LOG"
case "$1" in
  choose) printf '%s\n' "$FAKE_GUM_CHOICE" ;;
  input) printf '%s\n' "$FAKE_GUM_INPUT" ;;
  confirm) exit "${FAKE_GUM_CONFIRM_STATUS:-0}" ;;
esac
EOF
  write_fake_command firewall-cmd <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'firewall-cmd %s\n' "$*" >>"$COMMAND_LOG"
case "$1" in
  --query-service=ssh) [[ "${FAKE_FIREWALL_ALLOWS_SSH:-1}" -eq 1 ]] ;;
esac
EOF
  write_fake_command rpm <<'EOF'
#!/usr/bin/env bash
printf 'rpm %s\n' "$*" >>"$COMMAND_LOG"
exit "${FAKE_RPM_MISSING:-0}"
EOF
  make_fake_command dnf
  touch "$FAKE_STATE/firewalld.service.active"
}

zz_ssh() {
  PATH="$FAKE_BIN:$PATH" run bash "$ROOT_DIR/bin/zz" ssh "$@"
}

assert_hardened() {
  [[ -f "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" ]]
  assert_file_line "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" "PasswordAuthentication no"
  assert_file_line "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" "KbdInteractiveAuthentication no"
  [[ -f "$FAKE_STATE/sshd.service.enabled" ]]
  [[ -f "$FAKE_STATE/sshd.service.active" ]]
}

@test "zz ssh exposes its commands" {
  run bash "$ROOT_DIR/bin/zz" ssh --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "zz ssh <command>"
  assert_contains "$output" "setup"
  assert_contains "$output" "status"
  assert_contains "$output" "remove"

  run bash "$ROOT_DIR/bin/zz" ssh bogus
  [ "$status" -ne 0 ]
  assert_contains "$output" "Unknown zz ssh command: bogus"

  run bash "$ROOT_DIR/bin/zz" commands --json
  [ "$status" -eq 0 ]
  assert_contains "$output" '"name":"ssh"'
}

@test "zz ssh setup asks for a GitHub username, shows fingerprints, and hardens after the key is authorized" {
  printf '%s\n\nnot a key at all\n%s\n' "$FIRST_KEY" "$SECOND_KEY" >"$FAKE_STATE/github.keys"
  export FAKE_GUM_CHOICE="Fetch my public keys from GitHub"
  export FAKE_GUM_INPUT="octocat"

  zz_ssh setup
  [ "$status" -eq 0 ]
  assert_file_contains "$COMMAND_LOG" "curl -fsSL https://github.example/octocat.keys"
  assert_contains "$output" "GitHub publishes these keys for octocat"
  assert_contains "$output" "$FIRST_FINGERPRINT"
  assert_contains "$output" "$SECOND_FINGERPRINT"
  assert_file_contains "$COMMAND_LOG" "gum confirm"

  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_MATERIAL # zz ssh github:octocat"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$SECOND_MATERIAL # zz ssh github:octocat"
  refute_file_contains "$TARGET_HOME/.ssh/authorized_keys" "not a key at all"
  [ "$(stat -c '%a' "$TARGET_HOME/.ssh")" = "700" ]
  [ "$(stat -c '%a' "$TARGET_HOME/.ssh/authorized_keys")" = "600" ]
  assert_hardened
  assert_contains "$output" "accepts authorized keys only"

  # The drop-in is proven before the server comes up, and the stock firewall
  # zone already allows ssh, so nothing is added to it.
  run awk '/sshd -T/ { seen_check = NR } /systemctl enable --now sshd.service/ { enabled = NR } END { exit !(seen_check && enabled && seen_check < enabled) }' "$COMMAND_LOG"
  [ "$status" -eq 0 ]
  refute_file_contains "$COMMAND_LOG" "firewall-cmd --permanent --add-service=ssh"
  refute_file_contains "$COMMAND_LOG" "dnf install"
}

@test "zz ssh setup rerun syncs the GitHub keys and leaves pasted keys alone" {
  export ZZ_NO_TUI=1
  zz_ssh setup --key "$SECOND_KEY"
  [ "$status" -eq 0 ]

  export ZZ_NO_TUI=0
  export FAKE_GUM_CHOICE="Fetch my public keys from GitHub"
  export FAKE_GUM_INPUT="octocat"
  printf '%s\n%s\n' "$FIRST_KEY" "$SECOND_KEY" >"$FAKE_STATE/github.keys"
  zz_ssh setup
  [ "$status" -eq 0 ]
  assert_contains "$output" "Authorized: "
  assert_contains "$output" "Already authorized by hand: "
  # The pasted key keeps its line; only the new one is marked.
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$SECOND_KEY"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_MATERIAL # zz ssh github:octocat"
  [ "$(grep -c . "$TARGET_HOME/.ssh/authorized_keys")" -eq 2 ]

  # GitHub now lists a third key and no longer the first: the rerun swaps
  # them and never touches the pasted one.
  ssh-keygen -q -t ed25519 -N '' -C 'third@test' -f "$TEST_ROOT/third" >/dev/null
  local third_material
  third_material="$(awk '{ print $1, $2 }' "$TEST_ROOT/third.pub")"
  printf '%s\n' "$(cat "$TEST_ROOT/third.pub")" >"$FAKE_STATE/github.keys"
  zz_ssh setup
  [ "$status" -eq 0 ]
  assert_contains "$output" "Removed (no longer on GitHub): "
  assert_contains "$output" "$FIRST_FINGERPRINT"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$SECOND_KEY"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$third_material # zz ssh github:octocat"
  refute_file_contains "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_MATERIAL"
  [ "$(grep -c . "$TARGET_HOME/.ssh/authorized_keys")" -eq 2 ]
  [ "$(stat -c '%a' "$TARGET_HOME/.ssh/authorized_keys")" = "600" ]

  # An unchanged list is a no-op that says so.
  zz_ssh setup
  [ "$status" -eq 0 ]
  assert_contains "$output" "Kept: "
  [ "$(grep -c . "$TARGET_HOME/.ssh/authorized_keys")" -eq 2 ]

  # Another account's imports live side by side.
  export FAKE_GUM_INPUT="hubot"
  printf '%s\n' "$FIRST_KEY" >"$FAKE_STATE/github.keys"
  zz_ssh setup
  [ "$status" -eq 0 ]
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$third_material # zz ssh github:octocat"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_MATERIAL # zz ssh github:hubot"
  [ "$(grep -c . "$TARGET_HOME/.ssh/authorized_keys")" -eq 3 ]

  zz_ssh status
  [ "$status" -eq 0 ]
  assert_contains "$output" "[GitHub octocat]"
  assert_contains "$output" "[GitHub hubot]"
}

@test "zz ssh setup writes nothing when the GitHub keys are declined, missing, or the username is malformed" {
  printf '%s\n' "$FIRST_KEY" >"$FAKE_STATE/github.keys"
  export FAKE_GUM_CHOICE="Fetch my public keys from GitHub"
  export FAKE_GUM_INPUT="octocat"
  export FAKE_GUM_CONFIRM_STATUS=1

  zz_ssh setup
  [ "$status" -ne 0 ]
  assert_contains "$output" "No keys authorized"
  [[ ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]
  [[ ! -e "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" ]]
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]

  unset FAKE_GUM_CONFIRM_STATUS
  export FAKE_CURL_FAIL=1
  zz_ssh setup
  [ "$status" -ne 0 ]
  assert_contains "$output" "Could not fetch any SSH keys for GitHub user octocat"
  [[ ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]

  unset FAKE_CURL_FAIL
  printf 'not a key\n' >"$FAKE_STATE/github.keys"
  zz_ssh setup
  [ "$status" -ne 0 ]
  assert_contains "$output" "No valid SSH keys are published for GitHub user octocat"
  [[ ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]

  export FAKE_GUM_INPUT="octo cat/../etc"
  zz_ssh setup
  [ "$status" -ne 0 ]
  assert_contains "$output" "Not a GitHub username"
  refute_file_contains "$COMMAND_LOG" "octo cat"
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]
}

@test "zz ssh setup accepts a pasted key and rejects an invalid one" {
  export FAKE_GUM_CHOICE="Paste a public key"
  export FAKE_GUM_INPUT="$FIRST_KEY"

  zz_ssh setup
  [ "$status" -eq 0 ]
  assert_contains "$output" "Authorized: "
  assert_contains "$output" "$FIRST_FINGERPRINT"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_KEY"
  assert_hardened

  rm -rf "$TARGET_HOME/.ssh" "$ZZ_SSH_SSHD_CONFIG_DIR" "$FAKE_STATE/sshd.service.enabled" "$FAKE_STATE/sshd.service.active"
  export FAKE_GUM_INPUT="ssh-ed25519 garbage"
  zz_ssh setup
  [ "$status" -ne 0 ]
  assert_contains "$output" "Not a valid SSH public key"
  [[ ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]
}

@test "zz ssh setup --key runs unattended and is idempotent" {
  export ZZ_NO_TUI=1

  zz_ssh setup
  [ "$status" -ne 0 ]
  assert_contains "$output" "pass --key"
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]

  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -eq 0 ]
  refute_file_contains "$COMMAND_LOG" "gum "
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_KEY"
  assert_hardened

  zz_ssh setup "--key=$FIRST_KEY"
  [ "$status" -eq 0 ]
  assert_contains "$output" "Already authorized"
  [ "$(grep -c . "$TARGET_HOME/.ssh/authorized_keys")" -eq 1 ]
  assert_hardened
  # A running server is reloaded, not restarted, so a live session survives.
  assert_file_contains "$COMMAND_LOG" "systemctl reload sshd.service"
}

@test "zz ssh setup installs the server package and opens the firewall only when missing" {
  export ZZ_NO_TUI=1
  export FAKE_RPM_MISSING=1
  export FAKE_FIREWALL_ALLOWS_SSH=0

  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -eq 0 ]
  assert_file_contains "$COMMAND_LOG" "sudo dnf install -y openssh-server"
  assert_file_contains "$COMMAND_LOG" "sudo firewall-cmd --permanent --add-service=ssh"
  assert_file_contains "$COMMAND_LOG" "sudo firewall-cmd --reload"
  assert_hardened
}

@test "zz ssh setup removes a drop-in sshd rejects or ignores and leaves the server off" {
  export ZZ_NO_TUI=1
  export FAKE_SSHD_REJECT_CONFIG=1

  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -ne 0 ]
  assert_contains "$output" "sshd rejected the hardening drop-in"
  [[ ! -e "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" ]]
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_KEY"

  unset FAKE_SSHD_REJECT_CONFIG
  export FAKE_SSHD_IGNORE_DROPIN=1
  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -ne 0 ]
  assert_contains "$output" "did not apply the password-login restriction"
  [[ ! -e "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" ]]
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]
}

@test "zz ssh status reports the server, the keys, and the password-login state" {
  zz_ssh status
  [ "$status" -eq 0 ]
  assert_contains "$output" "sshd.service: not enabled, not running"
  assert_contains "$output" "none"
  refute_contains "$output" "Password logins"

  export ZZ_NO_TUI=1
  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -eq 0 ]

  zz_ssh status
  [ "$status" -eq 0 ]
  assert_contains "$output" "sshd.service: enabled, running"
  assert_contains "$output" "$FIRST_FINGERPRINT"
  assert_contains "$output" "off (authorized keys only)"

  rm -f "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf"
  zz_ssh status
  [ "$status" -eq 0 ]
  assert_contains "$output" "ON: the server accepts passwords"

  zz_ssh status --bogus
  [ "$status" -ne 0 ]
  assert_contains "$output" "Unknown zz ssh status option: --bogus"
}

@test "zz ssh remove disables the server, drops the restriction, and asks about the keys" {
  export ZZ_NO_TUI=1
  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -eq 0 ]

  export ZZ_NO_TUI=0
  export FAKE_GUM_CONFIRM_STATUS=1
  zz_ssh remove
  [ "$status" -eq 0 ]
  assert_file_contains "$COMMAND_LOG" "sudo systemctl disable --now sshd.service"
  [[ ! -e "$ZZ_SSH_SSHD_CONFIG_DIR/10-zz-fedora-hardening.conf" ]]
  [[ ! -e "$FAKE_STATE/sshd.service.enabled" ]]
  [[ ! -e "$FAKE_STATE/sshd.service.active" ]]
  assert_contains "$output" "Authorized keys kept"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_KEY"

  export FAKE_GUM_CONFIRM_STATUS=0
  zz_ssh remove
  [ "$status" -eq 0 ]
  assert_contains "$output" "Authorized keys removed"
  [[ ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]
}

@test "zz ssh remove decides about the keys from flags without prompting" {
  export ZZ_NO_TUI=1
  zz_ssh setup --key "$FIRST_KEY"
  [ "$status" -eq 0 ]

  # No gum and no flag keeps the keys.
  zz_ssh remove
  [ "$status" -eq 0 ]
  assert_contains "$output" "Authorized keys kept"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_KEY"

  export ZZ_NO_TUI=0
  zz_ssh remove --keep-keys
  [ "$status" -eq 0 ]
  refute_file_contains "$COMMAND_LOG" "gum confirm"
  assert_file_line "$TARGET_HOME/.ssh/authorized_keys" "$FIRST_KEY"

  zz_ssh remove --remove-keys
  [ "$status" -eq 0 ]
  refute_file_contains "$COMMAND_LOG" "gum confirm"
  [[ ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]

  zz_ssh remove --bogus
  [ "$status" -ne 0 ]
  assert_contains "$output" "Unknown zz ssh remove option: --bogus"
}
