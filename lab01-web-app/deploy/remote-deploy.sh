#!/usr/bin/env bash
# Runs ON the lab01 VM, as root, started by `az vm run-command` from the lab01-deploy workflow.
# It pulls the repo at ONE exact commit and applies the lab01 playbook to this machine itself
# (ansible-pull). GitHub never SSHes in, and no key or password is involved.
#
# Usage: remote-deploy.sh <git-sha> <key-vault-name> <vm-identity-client-id>
set -euo pipefail

SHA="$1" KV="$2" CLIENT_ID="$3"
REPO="https://github.com/ucimazing/azure-sre-labs.git"
export HOME=/root DEBIAN_FRONTEND=noninteractive   # run-command starts with an almost empty environment

# Keep a full log on the VM; run-command only returns the last ~4 KB of output to GitHub.
exec > >(tee -a /var/log/lab01-deploy.log) 2>&1
echo "=== lab01 deploy of ${SHA} at $(date -u +%FT%TZ)"

# First deploy only: install Ansible. Ubuntu's "ansible" package includes community.docker.
# (Better long-term: install it at VM creation with cloud-init, or bake it into the image with Packer.)
if ! command -v ansible-pull >/dev/null 2>&1; then
  echo "--- installing ansible"
  apt-get update -qq
  apt-get install -y -qq ansible >/dev/null
fi

# Clone/update the repo at the exact commit, then run the playbook against this VM (localhost).
ansible-pull \
  --url "$REPO" \
  --checkout "$SHA" \
  --directory /opt/ansible-pull/azure-sre-labs \
  --inventory localhost, \
  -e target=localhost \
  -e ansible_connection=local \
  -e app_version="$SHA" \
  -e key_vault_name="$KV" \
  -e vm_identity_client_id="$CLIENT_ID" \
  lab01-web-app/ansible/playbook.yml

# The workflow looks for this exact line. With `set -e`, any failure above means it never prints.
echo "DEPLOY_OK ${SHA}"
