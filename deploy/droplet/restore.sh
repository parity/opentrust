#!/usr/bin/env bash
# Restore a dump into a NEW database, so you can look at it (or swap it in) without touching live data.
#   ./restore.sh ~/backups/opentrust-20261007T012000Z.dump opentrust_restored
# It refuses to overwrite an existing database. To go live from a restored copy, see deploy/droplet/README.md ("A real restore").
set -euo pipefail
. "$(dirname "$0")/lib.sh"

dump="${1:?usage: restore.sh DUMPFILE NEW_DATABASE_NAME}"
target="${2:?usage: restore.sh DUMPFILE NEW_DATABASE_NAME}"
[ -f "$dump" ] || { echo "no such file: $dump" >&2; exit 1; }
case "$target" in opentrust|opentrust_shopify) echo "refusing to touch a live database; restore into a new name" >&2; exit 1;; esac
[[ "$target" =~ ^[a-z0-9_]+$ ]] || { echo "database name must be lowercase letters, digits and underscores" >&2; exit 1; }

if [ -f "$dump.sha256" ]; then
  expected="$(cut -d' ' -f1 "$dump.sha256")"
  actual="$({ command -v sha256sum > /dev/null && sha256sum "$dump" || shasum -a 256 "$dump"; } | cut -d' ' -f1)"
  [ "$expected" = "$actual" ] || { echo "checksum mismatch: the dump is damaged" >&2; exit 1; }
fi

# An encrypted dump (.enc) is decrypted to a private temporary file first, which is removed again on exit.
src="$dump"
if [[ "$dump" == *.enc ]]; then
  KEYFILE="${BACKUP_ENCRYPTION_KEY_FILE:-$(envval BACKUP_ENCRYPTION_KEY_FILE)}"
  [ -n "$KEYFILE" ] && [ -r "$KEYFILE" ] || { echo "this dump is encrypted: set BACKUP_ENCRYPTION_KEY_FILE to the key file it was made with" >&2; exit 1; }
  plain="$(umask 077; mktemp)"
  trap 'rm -f "$plain"' EXIT
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass "file:$KEYFILE" -in "$dump" -out "$plain" \
    || { echo "could not decrypt $dump: wrong key, or the file is damaged" >&2; exit 1; }
  src="$plain"
fi

# The app's login must own what it uses, so pick the owner from which database the dump came from.
case "$(basename "$dump")" in
  opentrust_shopify-*) owner=opentrust_shopify ;;
  opentrust-*)         owner=opentrust ;;
  *)                   owner=postgres ;;
esac
dc exec -T db createdb -U postgres -O "$owner" "$target"
dc exec -T db psql -U postgres -qc "REVOKE CONNECT ON DATABASE \"$target\" FROM PUBLIC; GRANT CONNECT ON DATABASE \"$target\" TO \"$owner\";"
dc exec -T db pg_restore -U postgres --no-acl -d "$target" < "$src"
log "restored $dump into database $target (owner: $owner)"
