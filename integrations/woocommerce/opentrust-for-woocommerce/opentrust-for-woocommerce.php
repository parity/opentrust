<?php
/**
 * Plugin Name:       OpenTrust for WooCommerce
 * Plugin URI:        https://opentrust.in/libraries
 * Description:       Check new orders' phone numbers against experiences shared by other Indian merchants on OpenTrust, and flag them for review. Never blocks checkout.
 * Version:           0.1.0
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Requires Plugins:  woocommerce
 * Author:            OpenTrust
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       opentrust-for-woocommerce
 * WC requires at least: 7.0
 */

defined( 'ABSPATH' ) || exit;

define( 'OPENTRUST_WC_VERSION', '0.1.0' );
define( 'OPENTRUST_WC_FILE', __FILE__ );

require_once __DIR__ . '/includes/class-client.php';
require_once __DIR__ . '/includes/class-reasons.php';
require_once __DIR__ . '/includes/class-checker.php';
require_once __DIR__ . '/includes/class-settings.php';
require_once __DIR__ . '/includes/class-order-box.php';
require_once __DIR__ . '/includes/class-plugin.php';

// Declare compatibility with High-Performance Order Storage and the block checkout.
add_action(
	'before_woocommerce_init',
	function () {
		if ( class_exists( '\Automattic\WooCommerce\Utilities\FeaturesUtil' ) ) {
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', OPENTRUST_WC_FILE, true );
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'cart_checkout_blocks', OPENTRUST_WC_FILE, true );
		}
	}
);

add_action(
	'plugins_loaded',
	function () {
		if ( class_exists( 'WooCommerce' ) ) {
			\OpenTrust\WooCommerce\Plugin::boot();
		}
	}
);
