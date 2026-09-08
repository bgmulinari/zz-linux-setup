#!/usr/bin/env bash
set -Eeuo pipefail

# Docker Engine install and post-install custom actions.

install_docker() {
  log_progress "Removing conflicting Docker packages"
  run_cmd_as_root dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine || true
  if ! fedora_repo_enabled docker-ce; then
    log_progress "Adding Docker CE repository"
    run_cmd_as_root dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  fi
  log_progress "Installing Docker Engine packages"
  run_cmd_as_root dnf install -y docker-ce docker-buildx-plugin docker-compose-plugin
}

verify_docker() {
  rpm -q \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin >/dev/null 2>&1
}

# The service comes with the engine; the docker group does not. Membership
# is root-equivalent (a container can bind-mount / and rewrite the host as
# root, with no password prompt), so it is its own opt-in choice
# (dev/docker-sudoless) and the default install leaves the daemon behind
# sudo.
configure_docker_post_install() {
  log_progress "Configuring Docker service"
  run_cmd_as_root systemctl daemon-reload
  run_cmd_as_root systemctl enable --now docker
}

verify_docker_post_install() {
  systemctl is-enabled docker.service >/dev/null 2>&1
}

docker_group_member() {
  id -nG "$TARGET_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker
}

install_docker_group() {
  if docker_group_member; then
    log_info "$TARGET_USER is already in the docker group"
    return 0
  fi
  log_progress "Adding $TARGET_USER to the docker group (root-equivalent Docker daemon access)"
  run_cmd_as_root usermod -aG docker "$TARGET_USER"
}

verify_docker_group() {
  docker_group_member
}

# remove-choice counterpart of install_docker_group; the engine and its
# service stay with the dev/docker choice.
remove_docker_group() {
  docker_group_member || return 0
  log_progress "Removing $TARGET_USER from the docker group"
  run_cmd_as_root gpasswd -d "$TARGET_USER" docker
}

register_action "docker" install_docker verify_docker
register_action "docker-post-install" configure_docker_post_install verify_docker_post_install
register_action "docker-group" install_docker_group verify_docker_group
