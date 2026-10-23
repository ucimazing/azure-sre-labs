#!/usr/bin/env bash
# Roll one app version out to Lab 2's servers, ONE server at a time, with no downtime:
#
#   for each server:  take it out of the App Gateway pool  -> wait for in-flight requests to drain
#                     -> run /opt/app/deploy.sh on it (pulls the version Key Vault names, swaps the container)
#                     -> put it back in the pool           -> wait until the App Gateway calls it Healthy
#
# The other servers carry all traffic while one is out. If ANY server fails, Key Vault goes back to
# the previous version and every server touched so far is rolled back the same way (automatic rollback).
#
# Usage:  rolling-deploy.sh <image-tag>         (the tag is a git commit SHA that exists in the registry)
# Needs:  az CLI logged in (the pipeline logs in with OIDC). Read-only checks run first; nothing changes
#         until the image is confirmed to exist and every server is healthy.
set -euo pipefail

TAG="${1:?usage: rolling-deploy.sh <image-tag>}"
[[ "$TAG" =~ ^[0-9a-f]{40}$ ]] || { echo "tag must be a full git commit SHA, got: $TAG"; exit 1; }
RG="${RESOURCE_GROUP:-rg-lab02-ha}"
APPGW="${APPGW_NAME:-agw-lab02}"
POOL="${APPGW_POOL:-app-pool}"
VMSS="${VMSS_NAME:-vmss-lab02-app}"
DRAIN_SECONDS="${DRAIN_SECONDS:-35}"   # App Gateway's drain timeout (30 s) plus a little margin
POLL_SECONDS="${POLL_SECONDS:-15}"
WAIT_TRIES="${WAIT_TRIES:-40}"          # 40 x 15 s = 10 minutes per wait, at most

log() { echo "[$(date -u +%T)] $*"; }
summary() { [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$*" >> "$GITHUB_STEP_SUMMARY"; return 0; }

# ---- what exists right now -------------------------------------------------------------------
ACR=$(az acr list -g "$RG" --query "[0].name" -o tsv)
KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv)
if [ -z "$ACR" ] || [ -z "$KV" ]; then log "no registry or Key Vault in $RG. Is Lab 2 up?"; exit 1; fi

POOL_ID=$(az network application-gateway address-pool show -g "$RG" --gateway-name "$APPGW" -n "$POOL" --query id -o tsv)

# The scale set's servers, as "vm-name nic-id" lines (autoscale may have added or removed some).
mapfile -t SERVERS < <(az vm list -g "$RG" \
  --query "[?virtualMachineScaleSet && ends_with(virtualMachineScaleSet.id, '/$VMSS')].[name, networkProfile.networkInterfaces[0].id]" -o tsv)
[ "${#SERVERS[@]}" -ge 2 ] || { log "need at least 2 servers for a zero-downtime deploy, found ${#SERVERS[@]}"; exit 1; }

# Health of one private IP as the App Gateway sees it: Healthy, Unhealthy, Unknown, or "absent" (not in the pool).
health_of() {
  local h
  h=$(az network application-gateway show-backend-health -g "$RG" -n "$APPGW" \
    --query "backendAddressPools[0].backendHttpSettingsCollection[0].servers[?address=='$1'].health | [0]" -o tsv 2>/dev/null || true)
  echo "${h:-absent}"
}

healthy_count() {
  az network application-gateway show-backend-health -g "$RG" -n "$APPGW" \
    --query "length(backendAddressPools[0].backendHttpSettingsCollection[0].servers[?health=='Healthy'])" -o tsv
}

# Wait until health_of(ip) == want. "absent" means the App Gateway no longer sends it anything.
wait_for() {
  local ip=$1 want=$2 got
  for i in $(seq 1 "$WAIT_TRIES"); do
    got=$(health_of "$ip")
    [ "$got" = "$want" ] && return 0
    log "  $ip is $got, waiting for $want ($i/$WAIT_TRIES)"
    sleep "$POLL_SECONDS"
  done
  log "  $ip never became $want"; return 1
}

ip_of() { az network nic show --ids "$1" --query "ipConfigurations[0].privateIPAddress" -o tsv; }
ipcfg_of() { az network nic show --ids "$1" --query "ipConfigurations[0].name" -o tsv; }
nic_name() { basename "$1"; }

pool_out() { az network nic ip-config address-pool remove -g "$RG" --nic-name "$(nic_name "$1")" -n "$(ipcfg_of "$1")" --address-pool "$POOL_ID" -o none; }
pool_in()  { az network nic ip-config address-pool add    -g "$RG" --nic-name "$(nic_name "$1")" -n "$(ipcfg_of "$1")" --address-pool "$POOL_ID" -o none; }

# Run deploy.sh on the server through the Azure agent (no SSH, no open port). run-command itself
# "succeeds" even when the script fails, so print the script's own exit code and check that.
run_deploy() {
  local out
  # shellcheck disable=SC2016  # single quotes on purpose: $? and $rc are evaluated on the server
  out=$(az vm run-command invoke -g "$RG" -n "$1" --command-id RunShellScript \
    --scripts '/opt/app/deploy.sh; rc=$?; tail -n 25 /var/log/app-deploy.log; echo "DEPLOY_RC=$rc"' \
    --query "value[0].message" -o tsv)
  while IFS= read -r l; do echo "    | $l"; done <<<"$out"
  grep -q "DEPLOY_RC=0" <<<"$out"
}

# One server, start to finish. Always tries to put the server back in the pool: if the new version
# is broken, the App Gateway's probe keeps it from getting traffic anyway.
deploy_one() {
  local vm=$1 nic=$2 ip ok=0
  ip=$(ip_of "$nic")
  log "--- $vm ($ip)"
  log "  taking it out of the pool"
  pool_out "$nic"
  wait_for "$ip" absent || true          # older App Gateway health views may lag; draining still applies
  log "  draining in-flight requests for ${DRAIN_SECONDS}s"
  sleep "$DRAIN_SECONDS"
  log "  running deploy.sh"
  run_deploy "$vm" || ok=1
  log "  putting it back in the pool"
  pool_in "$nic"
  if [ "$ok" -eq 0 ] && wait_for "$ip" Healthy; then
    log "  $vm is Healthy again"; return 0
  fi
  log "  $vm FAILED"; return 1
}

# ---- 1. checks before changing anything ------------------------------------------------------
log "image check: $ACR.azurecr.io/sre-lab-app:$TAG"
az acr repository show -n "$ACR" --image "sre-lab-app:$TAG" -o none \
  || { log "that image does not exist. Did the lab02-image pipeline finish?"; exit 1; }

HEALTHY=$(healthy_count)
log "servers: ${#SERVERS[@]}, healthy behind the App Gateway: $HEALTHY"
[ "$HEALTHY" -ge "${#SERVERS[@]}" ] \
  || { log "not every server is healthy. Fix that first: taking one out now could cause an outage."; exit 1; }

PREV=$(az keyvault secret show --vault-name "$KV" -n app-image-tag --query value -o tsv 2>/dev/null || true)
log "current version: ${PREV:-none}   new version: $TAG"
summary "### Rolling deploy of \`sre-lab-app:${TAG::7}\` (was \`${PREV::7}\`)"

# ---- 2. the new version becomes the desired one (new servers from autoscale/repair boot it too) ----
az keyvault secret set --vault-name "$KV" -n app-image-tag --value "$TAG" -o none

# ---- 3. one server at a time ------------------------------------------------------------------
DONE=()
for line in "${SERVERS[@]}"; do
  read -r vm nic <<<"$line"
  if deploy_one "$vm" "$nic"; then
    DONE+=("$line"); summary "- ✅ $vm"
    continue
  fi

  # ---- 4. automatic rollback ----------------------------------------------------------------
  summary "- ❌ $vm failed: rolling back to \`${PREV::7}\`"
  if [ -z "$PREV" ]; then log "no previous version to roll back to"; exit 1; fi
  log "=== ROLLBACK to $PREV"
  az keyvault secret set --vault-name "$KV" -n app-image-tag --value "$PREV" -o none
  for back in "$line" "${DONE[@]}"; do
    read -r bvm bnic <<<"$back"
    deploy_one "$bvm" "$bnic" || log "rollback of $bvm failed too: check it by hand"
  done
  summary "Rolled back. Read the failed server's output above (deploy.sh log)."
  exit 1
done

log "=== all ${#SERVERS[@]} servers run sre-lab-app:$TAG"
summary "All ${#SERVERS[@]} servers run the new version, one at a time, with the others serving traffic."
