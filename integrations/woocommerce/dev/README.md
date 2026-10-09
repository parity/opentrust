# Trying the WooCommerce plugin locally

A throwaway WordPress + WooCommerce in Docker, talking to an OpenTrust app running on your machine
(`bin/rails server -p 3000`). Needs Docker. Nothing is installed on your computer.

1. Let the Rails dev server accept requests from Docker: add `config.hosts << "host.docker.internal"` to
   `config/environments/development.rb` (temporary, don't commit) and restart it.
2. In OpenTrust, create an API key for a test merchant (portal, or `ApiKey.issue!`) and save it to
   `scripts/key.txt` (git-ignored). Report one number so there is something to find, e.g. `9812340077`.
3. Start and install:

       cd integrations/woocommerce/dev
       docker compose up -d
       wp() { docker compose run --rm -T cli wp --path=/var/www/html "$@"; }
       wp core install --url=http://localhost:8088 --title="OT Test" --admin_user=admin --admin_password=admin-pass-123 --admin_email=a@example.test --skip-email
       wp plugin install woocommerce --activate
       wp plugin activate opentrust-for-woocommerce

4. Run the scenarios (COD/prepaid, reported/clean, hold-on-report, cache, wrong key, outage):

       wp eval-file /scripts/scenarios.php

5. Try the UI at http://localhost:8088/wp-admin (admin / admin-pass-123): WooCommerce > OpenTrust, and the
   OpenTrust box on any order. Tear down with `docker compose --profile tools down -v`.

`mu-plugins/opentrust-test.php` points the plugin at the host app (`host.docker.internal:3000`) and can be
switched to a dead address to simulate an outage. It is test-only.
