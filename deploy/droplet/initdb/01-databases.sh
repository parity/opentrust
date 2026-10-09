#!/bin/sh
# Runs once, the first time the database starts with an empty data directory.
# One database and one login per app, so neither can read the other's data.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
CREATE ROLE opentrust LOGIN PASSWORD '${OPENTRUST_DB_PASSWORD}';
CREATE ROLE opentrust_shopify LOGIN PASSWORD '${SHOPIFY_DB_PASSWORD}';
CREATE DATABASE opentrust OWNER opentrust;
CREATE DATABASE opentrust_shopify OWNER opentrust_shopify;
REVOKE CONNECT ON DATABASE opentrust FROM PUBLIC;
REVOKE CONNECT ON DATABASE opentrust_shopify FROM PUBLIC;
GRANT CONNECT ON DATABASE opentrust TO opentrust;
GRANT CONNECT ON DATABASE opentrust_shopify TO opentrust_shopify;
SQL
