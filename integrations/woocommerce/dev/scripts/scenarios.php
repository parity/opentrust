<?php
use OpenTrust\WooCommerce\Checker;

$key = trim( file_get_contents( "/scripts/key.txt" ) ); // create this file with a throwaway OpenTrust API key (git-ignored)
function settings( $key, $cod = 'yes', $hold = 'no' ) { update_option( 'opentrust_wc_settings', array( 'api_key' => $key, 'only_cod' => $cod, 'hold_on_report' => $hold ) ); }
function pending() { return count( as_get_scheduled_actions( array( 'hook' => 'opentrust_wc_check_order', 'status' => 'pending' ), 'ids' ) ); }
function place( $phone, $method ) {
	$o = wc_create_order();
	$o->set_billing_first_name( 'Test' ); $o->set_billing_phone( $phone ); $o->set_payment_method( $method );
	$o->set_status( 'processing' ); $o->save();
	do_action( 'woocommerce_checkout_order_processed', $o->get_id(), array(), $o ); // what WooCommerce fires at checkout
	return $o->get_id();
}
function run_queue() { ActionScheduler_QueueRunner::instance()->run(); }
function show( $label, $id, $queued_before_run ) {
	$o = wc_get_order( $id ); $notes = array_map( function ( $n ) { return wp_strip_all_tags( $n->content ); }, wc_get_order_notes( array( 'order_id' => $id ) ) );
	echo json_encode( array( 'scenario' => $label, 'order' => $id, 'queued' => $queued_before_run, 'status' => $o->get_status(), 'opentrust' => $o->get_meta( Checker::META_STATUS ) ?: null, 'reports' => $o->get_meta( Checker::META_COUNT ), 'checked' => (bool) $o->get_meta( Checker::META_CHECKED ), 'notes' => $notes ), JSON_UNESCAPED_SLASHES ) . "\n";
}

delete_option( 'opentrust_test_base' );
settings( $key );
$id = place( '9812340077', 'cod' );   $q = pending(); run_queue(); show( 'A  COD, reported number', $id, $q );
$id = place( '9000000555', 'cod' );   $q = pending(); run_queue(); show( 'B  COD, clean number', $id, $q );
$id = place( '9812340077', 'razorpay' ); $q = pending(); run_queue(); show( 'C  prepaid (only_cod on)', $id, $q );
settings( $key, 'yes', 'yes' );
$id = place( '+91 98123 40077', 'cod' ); $q = pending(); run_queue(); show( 'D  hold-on-report, same number in another format (cache)', $id, $q );
settings( 'ot_live_wrongkey' );
$id = place( '9000000556', 'cod' );   $q = pending(); run_queue(); show( 'E  wrong API key', $id, $q );
settings( $key ); update_option( 'opentrust_test_base', 'http://host.docker.internal:9/api/v1' );
$id = place( '9000000557', 'cod' );   $q = pending(); run_queue(); show( 'F  OpenTrust unreachable', $id, $q );
delete_option( 'opentrust_test_base' );
