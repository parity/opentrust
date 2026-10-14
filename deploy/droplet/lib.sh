#!/usr/bin/env bash
# Shared by the other scripts. Source it:  . ./lib.sh
# `dc` is docker compose with this deployment's settings and the currently deployed images.
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KIT_DIR" || exit 1

# All settings live OUTSIDE the repository, root-owned and readable by deployer (see deploy/droplet/README.md).
ENV_FILE="${ENV_FILE:-/etc/opentrust/opentrust.env}"

# Docker needs root or the docker group. If deployer is NOT in the docker group (the stricter choice: docker-group
# membership is effectively passwordless root), run:  DOCKER="sudo docker" ./deploy.sh   (it will ask for your sudo password)
DOCKER="${DOCKER:-docker}"

touch images.env
# shellcheck disable=SC2086
dc() { $DOCKER compose --env-file "$ENV_FILE" --env-file images.env "$@"; }
log() { echo "$(date -u +%FT%TZ) $*"; }

# A setting from the env file ("" if absent). Values may be quoted.
envval() { grep -E "^$1=" "$ENV_FILE" 2> /dev/null | tail -1 | cut -d= -f2- | tr -d '"' || true; }

# Optional alerts. Both do nothing when their setting is empty, and neither can ever make the caller fail.
#   SLACK_WEBHOOK_URL  a Slack "incoming webhook": notify "text" posts a message there.
#   HEALTHCHECK_URL    a dead-man's-switch URL (healthchecks.io style): ping_check [start|fail] pings it, so you hear about a job that did NOT run.
# Either can also be set in the environment instead of the settings file. ALERT_LABEL names this server in messages.
notify() {
  local url="${SLACK_WEBHOOK_URL:-$(envval SLACK_WEBHOOK_URL)}"
  [ -n "$url" ] || return 0
  local label="${ALERT_LABEL:-$(envval ALERT_LABEL)}"
  local text="[${label:-opentrust} @ $(hostname)] $1"
  local json
  json="$(printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps({"text": sys.stdin.read().replace("\n", " ")}))' 2> /dev/null)" || return 0
  curl -fsS -m 10 -X POST -H 'Content-Type: application/json' --data "$json" "$url" > /dev/null 2>&1 || true
}

ping_check() {
  local url="${HEALTHCHECK_URL:-$(envval HEALTHCHECK_URL)}"
  [ -n "$url" ] || return 0
  curl -fsS -m 10 --retry 2 "${url%/}${1:+/$1}" > /dev/null 2>&1 || true
}

# Which compose profiles this deployment uses: how traffic gets in (ENTRY=tunnel|caddy), plus shopify if RUN_SHOPIFY=yes.
profile_flags() {
  local entry; entry="$(envval ENTRY)"; entry="${entry:-tunnel}"
  printf '%s\n' --profile "$entry"
  if [ "$(envval RUN_SHOPIFY)" = yes ]; then printf '%s\n' --profile shopify; fi
}
