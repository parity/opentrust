# Running OpenTrust on one server

A small, self-hosted setup for a single Linux server (we use a DigitalOcean Droplet): Postgres, the website and API, and a way
in. It is what runs opentrust.in. Prefer a managed platform? See [docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md).

## What you get

```
internet ─▶ Cloudflare ─▶ tunnel ─▶ web (Rails, port 3000) ─▶ db (Postgres, no published port)
```

- **Nothing is published on the server.** No web port, no database port. Traffic arrives through an outbound Cloudflare Tunnel
  (`ENTRY=tunnel`, the default), or through Caddy with automatic HTTPS (`ENTRY=caddy`, needs ports 80 and 443).
- **The database files** live in `$DATA_DIR/postgres`. Put `DATA_DIR` on a separate block-storage volume if you can, so the data
  survives rebuilding the server.
- **Settings are outside the repository**, in `/etc/opentrust/opentrust.env` (root-owned, readable by the deploy user, mode 640).
  Copy [.env.example](.env.example) there and fill it in. Generate every secret fresh; never reuse secrets between environments.

## You need

A Linux server with Docker and the Compose plugin, a non-root user to deploy as, a way to reach the repository (a read-only
deploy key for a private remote, or just `git clone` for a public one), a Cloudflare account for the tunnel, and a
[Resend](https://resend.com) API key for email. Lock the server down the usual way (SSH keys only, no root login, a cloud
firewall that allows only SSH).

## Generating secrets

```bash
openssl rand -hex 32   # SECRET_KEY_BASE, PHONE_HASH_PEPPER (never change it later: it breaks every existing match), ENCRYPTION_KEY (Shopify app)
openssl rand -hex 16   # AR_ENC_PRIMARY_KEY, AR_ENC_DETERMINISTIC_KEY, AR_ENC_SALT: run three times
openssl rand -hex 24   # POSTGRES_PASSWORD, OPENTRUST_DB_PASSWORD, SHOPIFY_DB_PASSWORD (hex is safe inside URLs)
```

Keep a copy of the settings file in a password manager; nothing restores without these secrets.

## Deploy and roll back

```bash
git clone <repository> ~/opentrust
sudo mkdir -p /etc/opentrust && sudo install -m 640 -o root -g "$USER" ~/opentrust/deploy/droplet/.env.example /etc/opentrust/opentrust.env
sudoedit /etc/opentrust/opentrust.env          # fill in every value
cd ~/opentrust/deploy/droplet && ./deploy.sh   # build, start, wait until healthy; rolls back by itself if it isn't
./deploy.sh <git-sha>                          # deploy a specific commit (rollback)
```

If your user is not in the `docker` group (membership is effectively root), use `DOCKER="sudo docker" ./deploy.sh`.

First admin (the password is read from a hidden prompt and never stored in a file):

```bash
. ./lib.sh
read -rsp 'Admin password: ' ADMIN_PASSWORD; echo
dc exec -T -e ADMIN_EMAIL=you@example.com -e ADMIN_PASSWORD="$ADMIN_PASSWORD" web ./bin/rails db:seed
unset ADMIN_PASSWORD
```

Put a Cloudflare Access policy (or similar) in front of `/admin*`.

### Rolling back a release that changed the database

`./deploy.sh <git-sha>` puts the old code back, **not** the old database. Most releases only add columns, which old code ignores, so that is fine. A release that rewrites existing data needs its migration reverted first, **while the new version is still running** (the old image does not contain the migration):

```bash
. ./lib.sh
dc exec -T web ./bin/rails db:rollback STEP=1     # revert the last migration
./deploy.sh <git-sha>                              # then deploy the old code
```

Take a backup (`./backup.sh`) before any deploy that includes a data migration. Releases like that say so in their commit message. For example, the release that introduced hashed phone numbers (migration `20261014120000`) re-keys every report: without reverting it, old code finds no reports and every lookup says "not reported". The revert works as long as every report still has its stored number; a report filed as a hash alone has none, and then the revert refuses to run.

## Backups

```bash
./backup.sh                                    # pg_dump of each database, checked with pg_restore --list, checksummed, rotated
crontab cron.example                           # every 6 hours, plus the nightly retention purge
```

**Dumps are encrypted** (AES-256) with a key file, and `backup.sh` refuses to run without one (or an explicit `BACKUP_ALLOW_UNENCRYPTED=yes`). Create the key once, and keep a copy in a password manager, because without it the backups cannot be restored:

```bash
openssl rand -base64 48 | sudo tee /etc/opentrust/backup.key > /dev/null
sudo chown root:"$USER" /etc/opentrust/backup.key && sudo chmod 640 /etc/opentrust/backup.key
# then set BACKUP_ENCRYPTION_KEY_FILE=/etc/opentrust/backup.key in the settings file
```

Encrypted dumps end in `.dump.enc`; `restore.sh` decrypts them with the same key and reads them like any other dump. Store the key somewhere other than where the dumps are uploaded.

Set `BACKUP_UPLOAD_CMD` in the settings file to a script that copies each dump **off the server**; a backup that lives only on the
machine it protects is not a backup. Cloud "droplet backups" usually don't include attached volumes, so the dumps are what
protect the data. Keep `BACKUP_KEEP_DAYS` short: removed reports are deleted from the database, and old dumps still hold them.

**Restore drill** (do it once before launch): into a new database, never over live data.

```bash
. ./lib.sh
./restore.sh ~/backups/opentrust-<stamp>.dump opentrust_restored
dc exec -T db psql -U postgres -d opentrust_restored -Atc 'select count(*) from merchants'
dc exec -T db dropdb -U postgres opentrust_restored
```

**A real restore** (a few seconds of downtime; the old database is kept as `opentrust_old`):

```bash
./restore.sh ~/backups/opentrust-<stamp>.dump opentrust_restored
dc stop web
dc exec -T db psql -U postgres -qAtc "select pg_terminate_backend(pid) from pg_stat_activity where datname in ('opentrust','opentrust_restored') and pid <> pg_backend_pid();"
dc exec -T db psql -U postgres -qc "ALTER DATABASE opentrust RENAME TO opentrust_old; ALTER DATABASE opentrust_restored RENAME TO opentrust;"
dc start web
```

## Alerts

Optional, and off until you set them in the settings file (see `.env.example`):

- `SLACK_WEBHOOK_URL`: a Slack incoming webhook. A failed deploy (build or health check, with the rollback), a failed backup (dump, encryption, or the off-server copy) and a failed nightly purge each post one message. A successful deploy posts a short note. A successful backup says nothing. The website uses the same webhook to tell you when a merchant has verified their email and is waiting for approval, with a button that opens the admin queue (approving still happens in the admin, behind the login).
- `HEALTHCHECK_URL`: a dead-man's-switch URL such as healthchecks.io. `backup.sh` pings it when it starts and when it finishes, so you are also told when a backup did **not run at all** (a stopped cron job, a dead server), which a script cannot report about itself.
- `ALERT_LABEL`: names the server in messages (`opentrust-prod`, `opentrust-staging`).

Neither can ever make a deploy or a backup fail or hang. Also set up an uptime check on `/up` and the host's CPU, memory and disk alerts with your provider.

## A second environment (staging)

Use a separate server if you can. On the same server, give it its own checkout, settings file, secrets and tunnel, and set these
in its settings file: `COMPOSE_PROJECT_NAME=opentrust-staging`, `DEPLOY_BRANCH=staging`, `NOINDEX=true`, and a different
`DATA_DIR`. Run its scripts with `ENV_FILE=/etc/opentrust/staging.env`. Protect it with an access policy; staging is for the
people you invited.

## Day to day

```bash
. ./lib.sh
dc ps                                          # what is running
dc logs -f --tail 100 web                      # logs (request paths only, never bodies; don't add phone-number logging)
dc exec -T web ./bin/rails console             # a console, when you really need one
```

Keep the operating system updated and watch CPU, memory and disk. Containers restart on boot. A Postgres *minor* update is
`dc pull db && dc up -d db`; a *major* upgrade is dump, new volume, restore, rehearsed first.

## What's here

| File | Purpose |
|---|---|
| `docker-compose.yml` | Postgres, web, optional Shopify app, and the tunnel or Caddy. Each service gets only the variables it needs. |
| `deploy.sh` | Fetch, build (images tagged by commit), start, health-check, automatic rollback |
| `backup.sh`, `restore.sh`, `purge.sh`, `cron.example` | Dumps, restores into a new database, the nightly retention purge, and their schedule |
| `lib.sh` | Shared helpers (`dc` is `docker compose` with this deployment's settings) |
| `initdb/` | Creates one database and one login per app, the first time Postgres starts |
| `Caddyfile` | Only for `ENTRY=caddy` |
| `.env.example` | Every setting |
