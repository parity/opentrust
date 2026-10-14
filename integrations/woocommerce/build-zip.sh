#!/usr/bin/env bash
# Builds the zip for WordPress.org (or Plugins > Add New > Upload): the plugin folder without tests.
# Usage: ./build-zip.sh [output-dir]   (default: ~/Desktop)
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-$HOME/Desktop}"
VERSION="$(sed -n 's/^ \* Version: *//p' opentrust-for-woocommerce/opentrust-for-woocommerce.php | head -1)"
ZIP="$OUT/opentrust-for-woocommerce-$VERSION.zip"
rm -f "$ZIP"
zip -qr "$ZIP" opentrust-for-woocommerce -x '*/tests/*' -x '*/.DS_Store'
echo "$ZIP"
unzip -l "$ZIP" | tail -n +4 | sed '$d' | awk '{print $4}'
