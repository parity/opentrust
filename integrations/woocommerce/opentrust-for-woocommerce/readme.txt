=== OpenTrust for WooCommerce ===
Contributors: opentrust
Tags: woocommerce, cod, fraud, orders, india
Requires at least: 6.0
Tested up to: 6.6
Requires PHP: 7.4
Stable tag: 0.1.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Check new orders' phone numbers against experiences shared by other Indian merchants, and flag them for review. Free. Never blocks checkout.

== Description ==

OpenTrust is a free, community-run notebook where Indian merchants note down mobile numbers that caused them trouble (refused COD orders, callers posing as a bank to get an OTP, and the like), and check new customers before they ship.

This plugin checks the billing phone number of new orders in the background, so checkout is never slowed, and adds a private note to the order if other merchants have noted experiences with that number. You can optionally put such orders on hold so you have a moment to review them.

* Checks run in the background after the order is placed. If OpenTrust is unreachable, the order carries on as normal.
* Works with the classic and block checkout, and High-Performance Order Storage.
* Only cash-on-delivery orders by default, which saves your checks.
* "Check now" and "Share an experience" on every order screen.
* Orders are never cancelled or blocked. Reports are unverified observations from individual merchants, not a finding about anyone, so you decide.

An OpenTrust account is free: [register here](https://opentrust.in/register).

== External service ==

This plugin sends data to the OpenTrust API at https://opentrust.in to do its job.

* **What is sent:** the billing phone number of an order that is checked, together with your API key. When you use "Share an experience", the phone number, the reason you choose and your note are sent too. Nothing else about the customer or the order is sent.
* **When:** after an order is placed (if it qualifies under your settings), and when you press "Check now" or "Share".
* **Service provider:** OpenTrust. [Terms](https://opentrust.in/terms) and [Privacy Policy](https://opentrust.in/privacy).

Please mention this in your own store's privacy policy.

== Installation ==

1. Install and activate the plugin.
2. Go to WooCommerce > OpenTrust and paste your API key from the [OpenTrust dashboard](https://opentrust.in/portal/api_keys).
3. Choose whether to check only COD orders and whether to put reported orders on hold.

== Frequently Asked Questions ==

= Will this block my customers? =
No. It never cancels or blocks an order, and it runs after the order is placed.

= How many checks do I get? =
Every approved merchant starts with 1,00,000 free checks. Need more? Write to feedback@opentrust.in.

= Does a report mean the customer committed fraud? =
No. Reports are unverified observations shared by individual merchants. Use them as one input among others and review the order yourself.

== Changelog ==

= 0.1.0 =
* First release.
