# Shopify App Store listing: draft text and checklist

The text to paste into the Partner Dashboard listing form. Field limits are as Shopify documented them when this was written; the form shows the real ones, so check the counts there. Keep the wording factual: reports are unverified observations, never a finding about anyone.

## Text

| Field | Text |
|---|---|
| **App name** (30) | OpenTrust |
| **Tagline / introduction** (100) | Check each new order's phone number against experiences other merchants shared. |
| **App details** (500) | OpenTrust checks each new order's phone number against experiences other Indian merchants have shared about problem numbers, such as disputed payments, fake orders or refused cash-on-delivery orders. If something was noted, the order is tagged and a note lists what was reported, so you can review it. It never cancels, holds or blocks an order. Reports are unverified observations, not a finding about anyone. Only the phone number is sent. Needs an OpenTrust API key. |
| **Feature 1** (80) | Checks each new order's phone number automatically |
| **Feature 2** (80) | Tags the order and adds a note listing what was reported |
| **Feature 3** (80) | Never cancels or blocks an order, and only the phone number is sent |
| **Pricing** | Free. The merchant creates a free OpenTrust account at opentrust.in to get an API key. |
| **Privacy policy URL** | https://opentrust.in/privacy |
| **Support email** | feedback@opentrust.in |
| **Support / FAQ page** | https://opentrust.in/faq |
| **Category** | The closest in Shopify's list (for example orders and shipping, or fraud and risk). |

## Images

- **App icon:** `assets/app-icon-1200.png` (1200 x 1200).
- **Screenshots** (1600 x 900, three to six, no personal data): (1) the settings screen with the key field empty and the explanation visible; (2) the settings screen saved, showing the "only cash-on-delivery" checkbox (off); (3) an order showing the `opentrust-reported` tag and the timeline note. Use the dev store with made-up customers only.
- **Screencast for review:** 2 to 3 minutes: install, paste the key, save, create an order for a number with a report, show the tag and note, show that the order is untouched otherwise.
  - **Recorded 12 Oct 2026 and uploaded (unlisted): https://youtu.be/F6c1R45ErVw** (2:34, voiceover; install, key, save, a reported number gets the tag and note, a clean order is untouched). Paste this link into the testing instructions field.
  - Known detail: the order note in it reads "Refused 3 COD orders in March 2026" (the demo report). Accurate, but COD-flavoured; re-record the order part with a chargeback report if that matters.

## Notes for the reviewer (the "testing instructions" field, NOT this file)

Use the **Demo Store** merchant on opentrust.in. Create a fresh key labelled `shopify_review` for the reviewer (the key shown in the screencast was revoked), and make sure one number has been reported by a *different* merchant, because a merchant's own reports are never shown to them. Fill the two placeholders below only in the Dashboard field. Never put the key or the number in the repository. After approval, revoke the key.

Text to paste (replace `<KEY>` and `<NUMBER>`):

> OpenTrust adds a tag and a note to an order when another merchant has reported the customer's phone number. It never cancels, holds or edits anything else, and it only sends the phone number.
>
> Test (about 3 minutes):
> 1. Install the app on your test store and open it (Apps, OpenTrust).
> 2. Paste this API key and click Save: `<KEY>`. The page should say "Connected as Demo Store". (A test account with free checks.)
> 3. Create an order (Orders, Create order) for a customer whose phone is `<NUMBER>` (put it in the customer's phone or the billing address). Any payment method works.
> 4. Within a few seconds, reload the order. It has the tag `opentrust-reported` and a timeline note listing what was reported.
> 5. Create a second order with a different phone number, for example +91 98765 12345. It is left untouched (no tag, no note), because nobody has reported it.
>
> By default every order with a phone number is checked. The checkbox "Only check cash-on-delivery orders" limits it to COD orders to save checks. A walkthrough video is here: https://youtu.be/F6c1R45ErVw
>
> Support: feedback@opentrust.in

## Before submitting

- [ ] Distribution set to the App Store (public) in the Dashboard. This choice cannot be undone for the app.
- [x] `npm audit --omit=dev` reports 0 (deepmerge-ts override, tested); the remaining findings are dev-only tooling.
- [ ] Data protection details answered truthfully (see the repo's `docs/INCIDENT-RESPONSE.md` and backup notes for the safeguards): encrypted backups with the key set on the server, incident policy adopted, admin password rule deployed.
- [ ] The privacy policy URL lists the Shopify app's data use (phone number only; nothing stored by the app besides the shop's encrypted key and a session).
- [ ] Mandatory privacy webhooks answer 200 on the real URL (`customers/data_request`, `customers/redact`, `shop/redact`).
- [ ] App listing wording reviewed by counsel.
