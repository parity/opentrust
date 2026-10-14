#!/usr/bin/env bash
# The nightly retention purge (deletes reports and audit logs past the periods the Privacy Policy states). Run by cron; see cron.example.
# A failure is reported to Slack when SLACK_WEBHOOK_URL is set.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
trap 'rc=$?; [ "$rc" -eq 0 ] || notify "❌ Nightly retention purge FAILED (exit $rc). Check ~/backups/purge.log"' EXIT
log "purging expired data"
dc exec -T web ./bin/rails opentrust:purge_expired
log "purge finished"
