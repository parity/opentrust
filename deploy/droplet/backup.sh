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

# Say so when a backup fails (and when it did not run at all, if HEALTHCHECK_URL is set), instead of failing quietly in a log.
STEP="starting"
upload_failed=0
trap 'rc=$?; if [ "$rc" -ne 0 ]; then notify "❌ Backup FAILED (exit $rc) while $STEP. Check $DIR/backup.log"; ping_check fail; fi' EXIT
ping_check start
# Dumps hold every merchant's data, so they are encrypted (AES-256) with a key file that is kept OFF the backup location.
# Without a key the script refuses to run, unless you explicitly accept plain-text dumps with BACKUP_ALLOW_UNENCRYPTED=yes.
KEYFILE="${BACKUP_ENCRYPTION_KEY_FILE:-$(envval BACKUP_ENCRYPTION_KEY_FILE)}"
ALLOW_PLAIN="${BACKUP_ALLOW_UNENCRYPTED:-$(envval BACKUP_ALLOW_UNENCRYPTED)}"
if [ -n "$KEYFILE" ] && [ ! -r "$KEYFILE" ]; then echo "BACKUP_ENCRYPTION_KEY_FILE is set but $KEYFILE cannot be read" >&2; exit 1; fi
if [ -z "$KEYFILE" ] && [ "$ALLOW_PLAIN" != yes ]; then
  echo "Set BACKUP_ENCRYPTION_KEY_FILE (see deploy/droplet/README.md) so dumps are encrypted, or BACKUP_ALLOW_UNENCRYPTED=yes to accept plain-text dumps." >&2
  exit 1
fi
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DIR"
umask 077

for db in opentrust opentrust_shopify; do
  out="$DIR/$db-$STAMP.dump"
  STEP="dumping $db"
  dc exec -T db pg_dump -U postgres -Fc "$db" > "$out.tmp"
  dc exec -T db pg_restore --list < "$out.tmp" > /dev/null   # refuse to keep a dump that can't be read back
  STEP="encrypting $db"
  if [ -n "$KEYFILE" ]; then
    openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -pass "file:$KEYFILE" -in "$out.tmp" -out "$out.enc.tmp"
    rm -f "$out.tmp"
    mv "$out.enc.tmp" "$out.enc"
    out="$out.enc"
  else
    mv "$out.tmp" "$out"
  fi
  { command -v sha256sum > /dev/null && sha256sum "$out" || shasum -a 256 "$out"; } > "$out.sha256"
  log "backed up $db -> $out ($(du -h "$out" | cut -f1))"

  if [ -n "$UPLOAD" ]; then
    STEP="uploading $db"
    # A failed upload must not pass quietly: an && list does not trip `set -e`, so check it explicitly and finish the other database first.
    if "$UPLOAD" "$out" && "$UPLOAD" "$out.sha256"; then
      log "uploaded $out"
    else
      log "ERROR: uploading $out FAILED"
      upload_failed=1
    fi
  else
    log "WARNING: BACKUP_UPLOAD_CMD is not set, so this backup exists only on this server"
  fi
done

# Keep BACKUP_KEEP_DAYS days. Keep this short: the Privacy Policy says removed reports are deleted, and old dumps still hold them.
STEP="removing old backups"
find "$DIR" -name '*.dump*' -mtime +"$KEEP" -delete

if [ "$upload_failed" -ne 0 ]; then STEP="copying to the off-server storage"; exit 1; fi   # the EXIT trap above reports it
ping_check
