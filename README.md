<p align="center"><img src="app/assets/images/logo/opentrust-logo.png" alt="OpenTrust" height="72"></p>

# OpenTrust

A free, community-run way for Indian merchants to share experiences with problem mobile numbers (chargebacks and disputed payments, fake orders, callers posing as a bank to get an OTP, refused COD orders, and the like) and to check new customers before they fulfil an order. Live at [opentrust.in](https://opentrust.in).

Sponsored and maintained by [ParityCube](https://www.paritycube.com/). Built proudly in India, for India.

> Reports are unverified observations shared by individual merchants. They are not a finding that anyone committed fraud. See the Terms and Privacy Policy in the app .

## What's in this repo

| Path | What |
|---|---|
| `app/`, `config/`, `db/` | The Rails 7.1 + Postgres app: website, merchant portal, admin, and the JSON API (`/api/v1`) |
| `sdks/ruby` | `opentrust` Ruby gem (no dependencies) |
| `sdks/node` | `opentrust` npm package (no dependencies, TypeScript types included) |
| `public/openapi.yml` | OpenAPI 3 description of the API |
| `spec/` | RSpec tests for the app |

Shopify and WooCommerce integrations are planned.

## Run it locally

    bundle install
    bin/rails db:setup      # creates the databases and seeds a dev admin and demo merchant
    bin/dev                 # web server + Tailwind watcher
    bundle exec rspec

Development logins are printed by the seed script and exist only in the development database. In development, emails are written to `tmp/mails/` and the verification code is shown on the page.

## Deploying

Two ways to run it: [deploy/droplet/README.md](deploy/droplet/README.md) (one server with Docker: Postgres, the app and a Cloudflare Tunnel, with backups and rollback) and [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) (DigitalOcean App Platform with a managed database). Environment variables are listed in [.env.example](.env.example).

## Configuration (production)

Nothing secret lives in this repo. Set these as environment variables:

- `SECRET_KEY_BASE`, `DATABASE_URL`
- `PHONE_HASH_PEPPER`: key for the HMAC used to match numbers. Treat it like a password and never rotate it casually, because that breaks every existing lookup.
- `AR_ENC_PRIMARY_KEY`, `AR_ENC_DETERMINISTIC_KEY`, `AR_ENC_SALT`: Active Record encryption keys (`bin/rails db:encryption:init`).
- `RESEND_API_KEY`, `MAIL_FROM`, `APP_HOST`: transactional email through [Resend](https://resend.com). Verify the sending domain (SPF and DKIM) first.
- `ADMIN_EMAIL`, `ADMIN_PASSWORD`: required to seed the first admin in production.
- Optional: `FEEDBACK_EMAIL`, `GRIEVANCE_EMAIL`, `COFFEE_URL`, `REPO_URL`, `SDKS_PUBLISHED`.

The app refuses to boot in production without the pepper and encryption keys.

## How it works

- Phone numbers are normalised to `+91XXXXXXXXXX`, stored as a keyed hash for matching plus an encrypted copy that only admins can read. API responses return only the last 4 digits and never the reporting merchant.
- Every approved merchant gets an allowance of checks (`OpenTrust::FREE_CHECKS`). Sharing is voluntary and earns nothing. All balance changes go through `Checks::Ledger`.
- API keys are shown once and stored as SHA-256 digests.

## Contributing

Issues and pull requests are welcome. Please keep reports and notes factual in any examples, and never include real phone numbers or personal data in issues, tests or screenshots.

## Security

Found a vulnerability? Please don't open a public issue. Email **jimish@paritycube.com** with the details; see [SECURITY.md](SECURITY.md).

## License

The code in this repository is released under the [MIT License](LICENSE), copyright Parity Cube Pvt Ltd and OpenTrust contributors.

What the MIT License does **not** cover:

- **The OpenTrust name, logo and mascot** (`docs/brand/`, `app/assets/images/logo/`, the icons and the scene artwork). You may use them to refer to this project; please don't use them to name or brand your own product or a lookalike service.
- **Third-party logos** shown on the site (for example Zingoy's), which belong to their owners and are used with permission.
- **Shopify's app template.** The files under `integrations/shopify/app/` that come from Shopify's template are MIT licensed, © Shopify Inc. (see `integrations/shopify/app/LICENSE.md`).
- **The WooCommerce plugin** (`integrations/woocommerce/opentrust-for-woocommerce/`) is GPL-2.0-or-later, because WordPress.org requires it.

---

OpenTrust is sponsored by [ParityCube](https://www.paritycube.com/) (Parity Cube Pvt Ltd), who run it as a community project and do not charge for it.
