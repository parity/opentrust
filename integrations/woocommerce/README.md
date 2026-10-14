# OpenTrust for WooCommerce

A WordPress plugin that checks the billing phone number of new orders against OpenTrust in the background (so checkout is never slowed), adds a private order note when other merchants have noted experiences with the number, and can optionally put those orders on hold. It never cancels or blocks an order and fails open.

- Works with the classic and block checkout, and High-Performance Order Storage.
- Checks every order with a phone number by default; an option limits it to cash-on-delivery orders to save checks.
- An "OpenTrust" box on every order screen: "Check now" and "Share an experience".
- Settings: WooCommerce > OpenTrust.

## Layout

    opentrust-for-woocommerce/
      opentrust-for-woocommerce.php   bootstrap, compatibility declarations
      includes/class-client.php       API client (injectable transport)
      includes/class-checker.php      the logic: who to check, record the result, fail open
      includes/class-plugin.php       hooks, background job
      includes/class-settings.php     settings page
      includes/class-order-box.php    order-screen box and its handlers
      readme.txt                      WordPress.org readme, including the required external-service disclosure
      tests/run.php                   dependency-free tests

## Tests

    php opentrust-for-woocommerce/tests/run.php

These cover the client and checker with a fake order (run on PHP 7.4 and 8.2). The WordPress-facing glue was also tried end to end in WordPress 7.1 with WooCommerce 11.1: new COD orders checked in the background and annotated, prepaid orders skipped, hold-on-report, caching across phone formats, wrong key, outage fail-open, the settings page, and the order screen's "Check now" and "Share an experience" buttons. `dev/` has the Docker setup to repeat it (see `dev/README.md`).

## Notes for WordPress.org

- The plugin is GPL-2.0-or-later, as the directory requires. (The OpenTrust SDKs are MIT, which is GPL-compatible.)
- The readme discloses the external service, what is sent and when, as the review guidelines require.
- Zip the `opentrust-for-woocommerce` folder to install it manually: Plugins > Add New > Upload.
