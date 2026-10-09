# Deploying OpenTrust on DigitalOcean

> **Two ways to deploy.** This guide uses **DigitalOcean App Platform** with a managed database (less to run yourself). If you'd rather run one server yourself, use **[deploy/droplet/README.md](../deploy/droplet/README.md)**: Docker with Postgres, the app and a Cloudflare Tunnel, backups and automatic rollback. The settings and the post-deploy checklist are the same.

This is the runbook for taking OpenTrust live on **DigitalOcean App Platform** with a **managed PostgreSQL** database, in the **Bangalore (BLR)** region. It covers the main site and API, the nightly cleanup job, the Shopify app, domains, email, and what to check after every deploy.

## What is verified, and what isn't

| Verified before writing this guide | How |
|---|---|
| The production Docker image builds, starts as a non-root user and serves the site on port 3000 | Built and run locally against PostgreSQL |
| First-deploy path: `db:prepare` on a brand-new database succeeds, the app comes up healthy, the admin seed works | Run in the container against an empty database |
| `/up` health check, all public pages, JSON API auth errors, the nightly cleanup command | Run in the container |
| The app refuses to start in production with missing, short or placeholder secrets | Tested |
| `.do/app.yaml` and `integrations/shopify/app/.do/app.yaml`: valid YAML, and every field name and value appears in DigitalOcean's official App Spec reference | Checked against the reference |
| App Platform is available in BLR; managed Postgres takes daily backups kept for 7 days | Read from DigitalOcean's documentation |

**Not yet verified: an actual deployment to your DigitalOcean account.** Steps marked **(confirm on first deploy)** depend on how your account and DNS are set up, and are the ones to watch for surprises.

## 1. What you'll run

| Piece | On DigitalOcean | Notes |
|---|---|---|
| Website, portal, admin, API | App Platform **web service**, built from the repo's `Dockerfile`, port 3000, health check `/up` | One instance. See "Know the limits". |
| Migrations | App Platform **pre-deploy job** (`./bin/rails db:prepare`) | Runs before each new version starts |
| Data retention | App Platform **scheduled job**, daily at 02:30 IST (`./bin/rails opentrust:purge_expired`) | Deletes what the Privacy Policy says we delete |
| Database | **Managed PostgreSQL**, one cluster, one database per app (`opentrust`, `opentrust_shopify`) | Daily automatic backups, kept 7 days |
| Shopify app | A second App Platform app (`opentrust-shopify`) from the same repo | Section 9 |
| Email | **Resend** | Section 6 |
| DNS and HTTPS | Your DNS provider (Cloudflare or DigitalOcean DNS); App Platform provisions the certificate | Section 5 |

## 2. Before you start

- [ ] A DigitalOcean account with billing set up, and the repository on **GitLab** (gitlab.com; private is fine, you'll connect your GitLab account to DigitalOcean once when you create the app).
- [ ] Access to the DNS for `opentrust.in`.
- [ ] A Resend account with the sending domain verified (section 6).
- [ ] The secrets from section 3 generated and saved in a password manager.
- [ ] `doctl` (DigitalOcean's CLI) installed and authenticated, if you want to create the app from the spec file instead of clicking through the panel: <https://docs.digitalocean.com/reference/doctl/how-to/install/>

## 3. Settings (environment variables)

Nothing secret is in the repository. In App Platform these are environment variables; mark secrets with **Encrypt** (type `SECRET`) so they are encrypted and hidden after saving. The spec file already declares them, with `REPLACE_IN_CONSOLE` as a placeholder.

| Variable | What it is | How to make it |
|---|---|---|
| `SECRET_KEY_BASE` | Signs sessions and cookies | `bin/rails secret` |
| `DATABASE_URL` | Postgres connection | Set to `${db.DATABASE_URL}` in the spec; DigitalOcean fills it in |
| `PHONE_HASH_PEPPER` | Key for the hash that matches phone numbers | `openssl rand -hex 32` |
| `AR_ENC_PRIMARY_KEY`, `AR_ENC_DETERMINISTIC_KEY`, `AR_ENC_SALT` | Encrypt the stored copy of each number | `bin/rails db:encryption:init` prints all three |
| `RESEND_API_KEY` | Sends email | Resend dashboard, "API keys" |
| `APP_HOST` | Public hostname | `opentrust.in` |
| `MAIL_FROM` | From address on emails | `OpenTrust <noreply@opentrust.in>` (the domain must be verified in Resend) |
| `FEEDBACK_EMAIL`, `GRIEVANCE_EMAIL` | Addresses shown to merchants. Point them at inboxes that exist | optional |
| `OPERATOR_NAME`, `OPERATOR_ADDRESS` | Legal entity in the Terms and Privacy Policy | optional (defaults to Parity Cube Pvt Ltd) |
| `GRIEVANCE_OFFICER_NAME`, `_DESIGNATION`, `_ADDRESS` | Grievance Officer in the Terms and Privacy Policy | optional |
| `COFFEE_URL`, `REPO_URL`, `SDKS_PUBLISHED` | Optional landing-page features | optional |

`ADMIN_EMAIL` and `ADMIN_PASSWORD` are **not** stored: you pass them once when creating the first admin (section 4, step 6).

**The app refuses to start in production** if `SECRET_KEY_BASE`, `PHONE_HASH_PEPPER` or any encryption key is missing, shorter than 16 characters, or looks like a placeholder (`REPLACE…`, `change-me`, `example`). That protects you from deploying the spec before filling in the real values.

> **Back up the pepper and the encryption keys somewhere safe, separate from the database.**
> - Lose or change `PHONE_HASH_PEPPER`, and every existing report stops matching: lookups silently return "nothing reported".
> - Lose the encryption keys, and the stored copies of numbers (what admins see) can no longer be read.
> Use the same values on every instance. Never rotate them casually.

## 4. First deploy, step by step

**1. Create a project.** In the control panel, create a project called "OpenTrust" to keep everything together.

**2. Create the database cluster.** Databases → Create → **PostgreSQL**, version 16, region **BLR1 (Bangalore)**, the smallest production plan to start. Name it `opentrust-db`. Then, on the cluster's **Users & Databases** tab, create two databases and a user for each:

| Database | User |
|---|---|
| `opentrust` | `opentrust` |
| `opentrust_shopify` | `opentrust_shopify` |

*(Confirm on first deploy: the spec names these in `db_name` and `db_user`. Creating them first is the safe order, because App Platform expects them to exist in an existing cluster.)*

**3. Make your private copy of the spec.** The committed `.do/app.yaml` has placeholders. Copy it, fill in real values locally, and keep the copy out of git (`.do/*.local.yaml` is already git-ignored):

```sh
cp .do/app.yaml .do/app.local.yaml
```

In `app.local.yaml`: replace `OWNER/opentrust` with your GitLab project path, `group/project` (in the web service **and** both jobs), and replace every `REPLACE_IN_CONSOLE` with the real secret. Values for `type: SECRET` variables are encrypted when you submit them.

**4. Create the app.**

```sh
doctl apps create --spec .do/app.local.yaml
```

Or in the panel: Apps → Create App → GitLab → your project; App Platform detects the `Dockerfile`; add the components and variables from the spec by hand. The first deploy builds the image (a few minutes), runs the **migrate** job, then starts the web service and waits for `/up`.

**5. Check it came up.** Open the app's `*.ondigitalocean.app` URL. The home page should load. The **Runtime Logs** tab shows Puma starting; the **Deployments** tab shows the pre-deploy job succeeded.

**6. Create the first admin (once).** In the app, open the web component's **Console** tab (*confirm on first deploy; if you don't see it, use* `doctl apps console <app-id> web`) and run:

```sh
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-long-random-password' ./bin/rails db:seed
```

In production the seed never uses a default password. With either value missing it skips quietly (that is what happens automatically on the first deploy), so nothing breaks. Log in at `/admin/login`.

**7. Add the domain.** App → Settings → Domains → Add `opentrust.in` as primary (the spec already lists it). Then see section 5.

**8. Set up email (section 6), then run the checklist (section 7).**

## 5. Domain and HTTPS

- App Platform provisions and renews the certificate for your domain. The app assumes TLS is terminated in front of it and **does not redirect HTTP to HTTPS itself**, so something in front must. *(Confirm on first deploy: open `http://opentrust.in` and check it lands on `https://`. If it doesn't, turn on Cloudflare's "Always Use HTTPS", or add a redirect rule at your DNS/CDN.)*
- **If DNS is on DigitalOcean:** add the domain to DigitalOcean Networking, point your registrar's nameservers at DigitalOcean, and App Platform creates the records itself.
- **If DNS stays on Cloudflare:** add the CNAME record DigitalOcean shows you (pointing at your app's `*.ondigitalocean.app` address). Set it to **DNS only** (grey cloud) until the domain shows "Active" and the certificate is issued; afterwards you may turn the Cloudflare proxy on with SSL mode **Full (strict)**. *(Confirm on first deploy: certificate issuance behind a proxy can fail until DNS-only is used.)*
- Add `www.opentrust.in` only if you want it; redirect it to the apex rather than serving both.

## 6. Email with Resend

1. In Resend, **add and verify your sending domain**. Resend shows DNS records (SPF, DKIM, optionally DMARC); add them where your DNS lives and wait for "Verified".
2. **Verify `opentrust.in` in Resend** (add the DNS records it gives you), then use `MAIL_FROM="OpenTrust <noreply@opentrust.in>"`. Add a DMARC record too. Resend only sends: forward feedback@ and grievance@ to a real inbox (for example with Cloudflare Email Routing) before launch.
3. Redeploy after changing `MAIL_FROM`. No code change.
4. Make sure the addresses shown to merchants (`FEEDBACK_EMAIL`, `GRIEVANCE_EMAIL`) are real inboxes.
5. If Resend is down, registration still works; the merchant sees "We couldn't send the email just now. Tap 'Send a new code'" and the error is logged.

## 7. After every deploy: checklist

- [ ] Deployments tab shows the **migrate** job and the web service succeeded.
- [ ] `GET /up` returns 200 on the public URL.
- [ ] Home, `/docs`, `/libraries`, `/faq`, `/terms`, `/privacy` load; the logo, favicon and the closed-window scene look right.
- [ ] **Register a test merchant.** The verification email arrives (check spam on the first run), the code works, and you land on "Waiting for approval".
- [ ] Log in at `/admin/login`, approve the test merchant, and confirm the approval email and 1,00,000 checks.
- [ ] Create an API key, then:
  ```sh
  curl -X POST https://opentrust.in/api/v1/lookups -H "Authorization: Bearer $KEY" -d phone=9876543210
  ```
  returns `report_count: 0`, a `notice`, and `checks_remaining` of 99,999.
- [ ] Share one experience; look the number up with a second merchant's key; confirm the response shows the reason and note and **never the merchant's name or the full number**.
- [ ] A wrong key returns 401; a bad number returns 422.
- [ ] The **purge-expired** job exists on the Settings → Jobs tab with the 02:30 IST schedule (you can trigger it once from the panel to see it succeed).
- [ ] Delete the test merchant's data if you used production for the test.

## 8. Running it

- **Deploys:** pushing to `main` on GitLab deploys automatically (`deploy_on_push`). The pre-deploy job migrates first; write migrations that are safe while the old version is still serving.
- **Rolling back:** Deployments tab → pick the last good deployment → **Redeploy**. Avoid rolling back past a migration unless you've written a down migration.
- **Logs:** Runtime Logs tab, or `doctl apps logs <app-id> web`. Logs hold request paths, never request bodies. Don't add logging of phone numbers. To keep logs longer, use App Platform's log forwarding.
- **Alerts:** the spec alerts you on failed deployments and domain problems, plus high memory and restarts on the web service. Add your email or Slack under Settings → Alerts.
- **Backups:** the managed database takes **automatic daily backups, kept for 7 days**, at a time DigitalOcean chooses. That is not long-term retention. For anything longer, run your own scheduled `pg_dump` to a private Spaces bucket (and keep the encryption keys and pepper separately, section 3).
- **Database access:** keep the cluster's **Trusted Sources** limited to the app (App Platform adds the app when it's attached; check it). If you want, switch `DATABASE_URL` to `${db.DATABASE_PRIVATE_URL}` so database traffic stays on DigitalOcean's private network.
- **Data retention:** the **purge-expired** job deletes reports 5 years after submission, removed reports after 90 days and audit logs after 3 years, as the Privacy Policy states. To keep a report past its date while a complaint or claim is open, set `legal_hold`: `FraudReport.where(id: 123).update_all(legal_hold: true)` in the Console. If you change the periods, change the Privacy Policy too (`RetentionPurge` holds the numbers).
- **Admin password:** there is no change-password screen yet. Reset one in the Console: `./bin/rails runner 'AdminUser.find_by!(email: "you@example.com").update!(password: "new-long-password")'`.
- **Sizing and cost:** the spec starts with one 1 GB container and one small managed database. Check DigitalOcean's current pricing page before choosing; scale the instance size up if memory alerts fire.

## 9. The Shopify app

A separate App Platform app, built from `integrations/shopify/app` with its own database in the same cluster. Spec: `integrations/shopify/app/.do/app.yaml`.

1. In the **Shopify Partner Dashboard**, create the app ("Create app" → "Create app manually" or via `shopify app init` / `shopify app config link` from `integrations/shopify/app`). Note the **Client ID** and **Client secret**.
2. Generate `ENCRYPTION_KEY` (`openssl rand -hex 32`) and save it with the other secrets.
3. Copy the spec to `app.local.yaml` (same folder), fill in the repo, `SHOPIFY_API_KEY` (Client ID), `SHOPIFY_API_SECRET`, `ENCRYPTION_KEY`, and set `SHOPIFY_APP_URL` to the domain you'll use (default `https://shopify.opentrust.in`):
   ```sh
   cp integrations/shopify/app/.do/app.yaml integrations/shopify/app/.do/app.local.yaml
   doctl apps create --spec integrations/shopify/app/.do/app.local.yaml
   ```
4. Add the domain `shopify.opentrust.in` (section 5).
5. Push the app's configuration (scopes, webhook URLs, app URL) to Shopify from `integrations/shopify/app`: set the `application_url` and redirect URLs to your domain, then `npm run deploy` (`shopify app deploy`).
6. Apply for **protected customer data access** in the Partner Dashboard. Without it the order webhook omits the phone number and the app can't work. See `integrations/shopify/app/README.md` for the full pre-submission checklist.
7. Install on a development store, paste an OpenTrust API key on the settings page, place a cash-on-delivery test order for a number someone has reported, and confirm the order gets the `opentrust-reported` tag and a note.

The app uses PostgreSQL because App Platform containers have no permanent disk (a SQLite file would be wiped on every deploy). Migrations run automatically when the container starts. Keep it at one instance.

## 10. Know the limits (v1)

- **Run one instance of the main app.** Rate-limit counters (Rack::Attack) live in each process's memory and emails use the in-process job queue, so more instances would each count separately, and a restart can drop an email that was queued but not sent (verification codes are sent immediately and aren't affected). Before scaling out, add a shared cache (Redis, for example DigitalOcean Managed Caching) and a real job queue.
- **Mobile numbers are not verified**, only emails. An SMS code needs a provider and, in India, DLT template registration.
- **Unverified registrations hold their email address.** Someone could register with another business's email and block them until you remove the record.
- **No account closing yet.** There is no self-serve way for a merchant to close their account.
- **Legal pages.** Get the Terms and Privacy Policy reviewed before any public announcement, and bump `LEGAL_VERSION` / `LEGAL_EFFECTIVE` in `config/initializers/opentrust.rb` whenever they change materially.

## 11. Releasing the libraries and integrations

Do these after the app is live and the docs are accurate.

**Ruby gem** (`sdks/ruby`, name `opentrust`)
```sh
cd sdks/ruby && ruby -Ilib test/client_test.rb
gem build opentrust.gemspec
gem push opentrust-0.1.0.gem      # needs a RubyGems account with MFA
```

**npm package** (`sdks/node`, name `opentrust`)
```sh
cd sdks/node && npm test
npm publish --access public       # needs an npm account with 2FA
```

Then set `SDKS_PUBLISHED=true` on the web service and redeploy; the docs drop the "about to be published" notice and add the SDK tabs.

**WooCommerce** (`integrations/woocommerce/opentrust-for-woocommerce`): tested in WordPress 7.1 with WooCommerce 11.1 (see `integrations/woocommerce/dev/`). Zip the folder and submit it to the WordPress.org plugin directory for review. Plugin icons are in `integrations/woocommerce/wordpress-org-assets/`.

**Shopify:** section 9. The app icon (1200×1200) is `integrations/shopify/assets/app-icon-1200.png`.

## Appendix: a single server instead (Droplet)

If you'd rather run one server yourself (cheaper, more work), a Droplet in Bangalore with Docker works too:

1. Create an Ubuntu Droplet (BLR1), add your SSH key, and a **Managed PostgreSQL** database (don't run the database on the same disk as the app).
2. Install Docker, then `git clone` the repo and `docker build -t opentrust .`.
3. Put the settings from section 3 in an env file (permissions `600`) and run:
   ```sh
   docker run -d --name opentrust --restart unless-stopped -p 127.0.0.1:3000:3000 --env-file /etc/opentrust.env opentrust
   ```
4. Put **Caddy** in front for automatic HTTPS: a `Caddyfile` with `opentrust.in { reverse_proxy 127.0.0.1:3000 }`.
5. Schedule the cleanup with cron: `30 2 * * * docker exec opentrust ./bin/rails opentrust:purge_expired`.
6. Back up the database with your own `pg_dump` schedule, and keep OS updates automatic.

Everything else in this guide (settings, checklist, limits) applies unchanged.
