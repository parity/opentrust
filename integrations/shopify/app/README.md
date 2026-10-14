# OpenTrust for Shopify (the app)

Checks the phone number on new orders against experiences shared by other Indian merchants on [OpenTrust](https://opentrust.in), then **tags the order `opentrust-reported` and adds a note** listing what was reported. It never cancels, holds or blocks an order, and fails open if OpenTrust can't be reached. Reports are unverified observations from individual merchants, not a finding about the customer.

Built on Shopify's [React Router app template](https://github.com/Shopify/shopify-app-template-react-router) (MIT, © Shopify Inc., see `LICENSE.md`). Everything OpenTrust-specific is in `app/opentrust/`, plus the routes below.

## What's verified, and what isn't

| | Status |
|---|---|
| Order checking, COD detection, tagging and notes via Admin GraphQL, encrypted key storage, settings, privacy webhooks | 29 automated tests (`npm test`), typecheck and production build pass |
| Real server run | Built app started; forged webhook signature gets **401**, correctly signed webhooks get **200**; a signed `orders/create` for a shop with a saved key read the key from PostgreSQL, decrypted it and made a real lookup against the OpenTrust API |
| **Not yet verified** | Installing on a real store, the embedded settings page inside the Shopify admin, and tagging a real order. These need a Shopify Partner app and a development store (below). |

## How it fits together

    Shopify ──orders/create webhook──▶ app/routes/webhooks.orders.create.tsx
                                         │  (HMAC-verified by Shopify's library)
                                         ▼
                                   app/opentrust/handlers.ts → processOrder
                                         │ 1. read phone, skip non-COD (if "only COD")
                                         │ 2. lookup via OpenTrust API (5 s timeout, fails open)
                                         │ 3. if reported: tagsAdd + append to order note (Admin GraphQL)
                                         ▼
                                   always answers 200 (Shopify retries anything else)

| File | Purpose |
|---|---|
| `app/routes/app._index.tsx` | Settings page (API key, "only COD" switch, connection status) |
| `app/routes/webhooks.orders.create.tsx` | The order check |
| `app/routes/webhooks.customers.*`, `webhooks.shop.redact.tsx`, `webhooks.app.uninstalled.tsx` | Mandatory privacy webhooks and cleanup |
| `app/opentrust/` | All the logic, framework-free and tested: `client.ts`, `order.ts`, `process-order.ts`, `handlers.ts`, `admin.ts`, `crypto.server.ts` |
| `prisma/schema.prisma` | `Session` (Shopify's) and `OpenTrustSettings` (one row per shop: encrypted key + one switch). **No customer or order data is stored.** |

**Data and security:** each shop's OpenTrust API key is encrypted (AES-256-GCM) with `ENCRYPTION_KEY` before it is stored, never shown back, and deleted on uninstall and `shop/redact`. Only the phone number is sent to opentrust.in. Phone numbers are never logged.

## Run it locally (needs a Shopify Partner account)

1. Install the [Shopify CLI](https://shopify.dev/docs/apps/tools/cli/getting-started) and make a [development store](https://shopify.dev/docs/apps/tools/development-stores) in your Partner Dashboard.
2. `cp .env.example .env`, set `ENCRYPTION_KEY` (`openssl rand -hex 32`), and create the database: `createdb opentrust_shopify_dev && npx prisma migrate deploy`.
3. `npm install`, then `npm run dev`. The CLI links the app to your Partner Dashboard app, fills in the Shopify settings and gives you a tunnel URL.
4. Install the app on the dev store, open it, paste an OpenTrust API key, and create a test order with a cash-on-delivery payment method for a number someone has reported.

To point at a local OpenTrust server while developing, set `OPENTRUST_BASE_URL=http://localhost:3000/api/v1`.

## Tests

    npm test            # Vitest: logic, client, and the webhook routes (Shopify's login layer faked)
    npm run typecheck
    npm run build

## Deploying

DigitalOcean App Platform: see [`docs/DEPLOYMENT.md`](../../../docs/DEPLOYMENT.md) (section "Shopify app") and `.do/app.yaml`.

## Before you submit to the Shopify App Store

- **Protected customer data.** Reading an order's phone number needs approval under "protected customer data" in the Partner Dashboard (a short questionnaire about why you need it, how it's protected and retained). Without it the webhook omits the phone and the app can't work. Apply early.
- **Mandatory privacy webhooks** are implemented (`customers/data_request`, `customers/redact`, `shop/redact`) and must be reachable at the URLs in `shopify.app.toml`.
- **COD detection.** Shopify has no COD flag; we match the payment method's name (`COD`, `Cash on Delivery`, `cash_on_delivery`). Stores that name it differently can turn off "only COD".
- **Listing text** should repeat that reports are unverified observations, and that only the phone number is shared with OpenTrust.
- Shopify's review also checks the embedded admin experience, scopes and the app's privacy policy URL (use `https://opentrust.in/privacy`).

## Dependency audit notes

`package.json` has an `overrides` entry for `deepmerge-ts` (8.x). Prisma's command-line tools depend on 7.x, which has a stack-exhaustion advisory, and no Prisma release has moved off it yet. The override was tested with `prisma generate`, `prisma migrate deploy` on a fresh database, the test suite and the production Docker build. Remove it once Prisma ships a version that uses 8.x. `npm audit --omit=dev` should report 0; the remaining findings are in development tooling (linting and code generation) that is not part of the production image.
