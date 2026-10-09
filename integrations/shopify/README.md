# OpenTrust for Shopify

Checks the phone number on new orders against experiences shared by other Indian merchants on OpenTrust, then tags the order `opentrust-reported` and adds a note listing what was reported. It never cancels, holds or blocks an order, and fails open if OpenTrust can't be reached.

The app lives in [`app/`](app/), built on Shopify's official React Router template. **See [`app/README.md`](app/README.md)** for what's verified, how to run it against a development store, how to deploy it, and the checklist for the Shopify App Store (including the "protected customer data" approval needed to read order phone numbers).

Status: the logic, webhooks and settings page are built and tested (29 tests, signed-webhook smoke test against the real built server). It has not yet been installed on a real Shopify store, which needs a Partner account and a development store.
