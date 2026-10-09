#!/usr/bin/env bash
# Logical backup of both databases (pg_dump custom format): checked, rotated, and handed to an upload command that copies
# each file OFF this server. Run as deployer. Typical cron (every 6 hours) is in cron.example.
#
# BACKUP_UPLOAD_CMD (set in the env file) is a script that takes one argument, the dump file, and copies it somewhere that is
# not this Droplet (a DigitalOcean Space, another server, ...). Without it the script warns that the backup exists only here.
#
# This is in addition to DigitalOcean's Droplet backups and volume snapshots, not instead of them: a dump you have restored
# once is the only backup you can really trust, and it is portable (it also restores onto a managed database).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DIR="${BACKUP_DIR:-$HOME/backups}"
KEEP="${BACKUP_KEEP_DAYS:-$(envval BACKUP_KEEP_DAYS)}"; KEEP="${KEEP:-14}"
UPLOAD="${BACKUP_UPLOAD_CMD:-$(envval BACKUP_UPLOAD_CMD)}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DIR"
umask 077

for db in opentrust opentrust_shopify; do
  out="$DIR/$db-$STAMP.dump"
  dc exec -T db pg_dump -U postgres -Fc "$db" > "$out.tmp"
  dc exec -T db pg_restore --list < "$out.tmp" > /dev/null   # refuse to keep a dump that can't be read back
  mv "$out.tmp" "$out"
  { command -v sha256sum > /dev/null && sha256sum "$out" || shasum -a 256 "$out"; } > "$out.sha256"
  log "backed up $db -> $out ($(du -h "$out" | cut -f1))"

  if [ -n "$UPLOAD" ]; then
    "$UPLOAD" "$out" && "$UPLOAD" "$out.sha256" && log "uploaded $out"
  else
    log "WARNING: BACKUP_UPLOAD_CMD is not set, so this backup exists only on this server"
  fi
done

# Keep BACKUP_KEEP_DAYS days. Keep this short: the Privacy Policy says removed reports are deleted, and old dumps still hold them.
find "$DIR" -name '*.dump*' -mtime +"$KEEP" -delete
