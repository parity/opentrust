<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

/** Wires the plugin into WooCommerce. Checks run in the background so checkout is never slowed. */
class Plugin {
	const ACTION = 'opentrust_wc_check_order';

	public static function boot() {
		Settings::hooks();
		OrderBox::hooks();

		// Classic checkout and the block checkout fire different hooks.
		add_action( 'woocommerce_checkout_order_processed', array( __CLASS__, 'on_new_order' ), 20, 1 );
		add_action( 'woocommerce_store_api_checkout_order_processed', array( __CLASS__, 'on_new_order' ), 20, 1 );
		add_action( self::ACTION, array( __CLASS__, 'run' ), 10, 1 );
		add_action( 'admin_init', array( __CLASS__, 'privacy_policy_text' ) );
		add_action( 'update_option_' . Settings::OPTION, function () { delete_transient( 'opentrust_wc_status' ); } );
	}

	/** @param int|\WC_Order $order_or_id */
	public static function on_new_order( $order_or_id ) {
		$order = wc_get_order( $order_or_id );
		if ( ! $order || '' === Settings::get()['api_key'] ) {
			return;
		}
		$checker = new Checker( Settings::client(), OrderBox::options() );
		if ( ! $checker->should_check( $order ) ) {
			return;
		}
		if ( function_exists( 'as_enqueue_async_action' ) ) {
			as_enqueue_async_action( self::ACTION, array( $order->get_id() ), 'opentrust' );
		} else {
			wp_schedule_single_event( time(), self::ACTION, array( $order->get_id() ) );
		}
	}

	public static function run( $order_id ) {
		$order = wc_get_order( $order_id );
		if ( ! $order ) {
			return;
		}
		$checker = new Checker( Settings::client(), OrderBox::options() );
		if ( $checker->should_check( $order ) ) {
			$checker->check_order( $order );
		}
	}

	public static function privacy_policy_text() {
		if ( function_exists( 'wp_add_privacy_policy_content' ) ) {
			wp_add_privacy_policy_content(
				'OpenTrust for WooCommerce',
				wp_kses_post( '<p>When enabled, this store sends the billing phone number of qualifying orders to OpenTrust (opentrust.in) to check whether other merchants have noted experiences with that number. No other customer or order details are sent. See <a href="https://opentrust.in/privacy">OpenTrust\'s Privacy Policy</a>.</p>' )
			);
		}
	}
}
