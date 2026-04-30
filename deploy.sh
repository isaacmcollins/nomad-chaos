#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$SCRIPT_DIR/nomad/jobs"
TF_DIR="$SCRIPT_DIR/tf"
PACKER_DIR="$SCRIPT_DIR/packer"

NOMAD_PORT=4646
NOMAD_READY_TIMEOUT=300 

JOBS=(
  traefik.nomad.hcl
  prometheus.nomad.hcl
  node-exporter.nomad.hcl
  nomad-app.nomad.hcl
)

log()  { echo "[$(date +%T)] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "'$cmd' not found in PATH"
  done
}

nomad_server_ts_ip() {
  local region="$1"
  tailscale status --json \
    | python3 -c "
        import sys, json
        data = json.load(sys.stdin)
        region = '$region'
        for peer in data.get('Peer', {}).values():
            hn = peer.get('HostName', '')
            if hn.startswith('ns-') and hn.endswith('-' + region):
                ips = peer.get('TailscaleIPs', [])
                if ips:
                    print(ips[0])
                    break
        "
}

wait_for_nomad() {
  local addr="$1"
  local deadline=$(( $(date +%s) + NOMAD_READY_TIMEOUT ))
  log "Waiting for Nomad API at $addr ..."
  until curl -sf "$addr/v1/status/leader" &>/dev/null; do
    if [[ $(date +%s) -ge $deadline ]]; then
      die "Timed out waiting for Nomad at $addr"
    fi
    sleep 5
  done
  log "Nomad at $addr is ready."
}

deploy_jobs() {
  local addr="$1"
  local region="$2"
  export NOMAD_ADDR="$addr"
  log "Deploying jobs to $region ($addr) ..."
  for job in "${JOBS[@]}"; do
    local path="$JOBS_DIR/$job"
    if [[ ! -f "$path" ]]; then
      log "  SKIP $job (file not found)"
      continue
    fi
    log "  nomad job run $job"
    nomad job run "$path"
  done
}

require terraform aws nomad curl tailscale python3 packer

log "=== Packer: building AMI ==="
cd "$PACKER_DIR"
packer init .
packer build -var 'regions=["us-east-1","us-west-2"]' .

cd "$TF_DIR"
terraform init -input=false
terraform apply -input=false -auto-approve

log "=== Discovering Nomad servers via Tailscale ==="

log "Waiting 30s for instances to join Tailscale ..."
sleep 30

EAST_IP=$(nomad_server_ts_ip "us-east-1")
WEST_IP=$(nomad_server_ts_ip "us-west-2")

[[ -z "$EAST_IP" ]] && die "No Tailscale peer matching ns-*-us-east-1 found. Is Tailscale up and the node online?"
[[ -z "$WEST_IP" ]] && die "No Tailscale peer matching ns-*-us-west-2 found. Is Tailscale up and the node online?"

EAST_ADDR="http://$EAST_IP:$NOMAD_PORT"
WEST_ADDR="http://$WEST_IP:$NOMAD_PORT"

log "  us-east-1 Nomad: $EAST_ADDR"
log "  us-west-2 Nomad: $WEST_ADDR"

log "=== Waiting for Nomad clusters to be ready ==="
wait_for_nomad "$EAST_ADDR"
wait_for_nomad "$WEST_ADDR"

log "=== Deploying Nomad jobs ==="
deploy_jobs "$EAST_ADDR" "us-east-1"

log ""
log "=== Done ==="
log "  East ALB:  http://$(cd "$TF_DIR" && terraform output -raw regional_alb_dns 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["us-east-1"])' 2>/dev/null || echo '<see terraform output regional_alb_dns>')"
log "  West ALB:  http://$(cd "$TF_DIR" && terraform output -raw regional_alb_dns 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["us-west-2"])' 2>/dev/null || echo '<see terraform output regional_alb_dns>')"
log "  Global:    http://$(cd "$TF_DIR" && terraform output -raw global_accelerator_dns 2>/dev/null || echo '<see terraform output global_accelerator_dns>')"
log ""
log "  Nomad UI (east): $EAST_ADDR/ui"
log "  Nomad UI (west): $WEST_ADDR/ui"
