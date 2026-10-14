<?php
// The plugin runs inside WordPress; these stand in for three WordPress functions so the tests can run on plain PHP.
if ( ! function_exists( 'esc_html' ) ) { function esc_html( $t ) { return htmlspecialchars( (string) $t, ENT_QUOTES, 'UTF-8' ); } }
if ( ! function_exists( 'wp_specialchars_decode' ) ) { function wp_specialchars_decode( $t, $q = ENT_QUOTES ) { return htmlspecialchars_decode( (string) $t, $q ); } }
if ( ! function_exists( 'wp_strip_all_tags' ) ) { function wp_strip_all_tags( $t ) { return strip_tags( (string) $t ); } }
// Dependency-free tests for the pure classes. Run: php tests/run.php
define( 'ABSPATH', __DIR__ . '/' );
require __DIR__ . '/../includes/class-client.php';
require __DIR__ . '/../includes/class-reasons.php';
require __DIR__ . '/../includes/class-checker.php';

use OpenTrust\WooCommerce\ApiException;
use OpenTrust\WooCommerce\Checker;
use OpenTrust\WooCommerce\Client;
use OpenTrust\WooCommerce\Reasons;

$failures = 0;
$total    = 0;
function check( $name, $cond ) {
	global $failures, $total;
	++$total;
	if ( ! $cond ) {
		++$failures;
		echo "FAIL: $name\n";
	}
}

class FakeOrder {
	public $meta = array(); public $notes = array(); public $status = 'processing'; public $saved = 0; public $phone; public $payment;
	public function __construct( $phone = '9876543210', $payment = 'cod' ) { $this->phone = $phone; $this->payment = $payment; }
	public function get_billing_phone() { return $this->phone; }
	public function get_payment_method() { return $this->payment; }
	public function get_meta( $k ) { return isset( $this->meta[ $k ] ) ? $this->meta[ $k ] : ''; }
	public function update_meta_data( $k, $v ) { $this->meta[ $k ] = $v; }
	public function save() { ++$this->saved; }
	public function add_order_note( $n ) { $this->notes[] = $n; }
	public function has_status( $s ) { return in_array( $this->status, (array) $s, true ); }
	public function update_status( $s, $note = '' ) { $this->status = $s; $this->notes[] = $note; }
}

function transport( $status, $body, &$seen = null ) {
	return function ( $method, $url, $headers, $payload, $timeout ) use ( $status, $body, &$seen ) {
		$seen = compact( 'method', 'url', 'headers', 'payload', 'timeout' );
		return array( $status, json_encode( $body ) );
	};
}
$reported = array( 'phone_last4' => '3210', 'report_count' => 2, 'reports' => array(
	array( 'reason_code' => 'cod_refusal', 'reason' => 'Refused a cash-on-delivery order', 'notes' => 'Refused 3 COD orders <b>x</b>', 'reported_at' => '2026-10-01' ),
	array( 'reason_code' => 'otp_fraud', 'reason' => 'Asked someone for an OTP', 'notes' => null, 'reported_at' => '2026-09-20' ),
) );
$clean = array( 'phone_last4' => '0001', 'report_count' => 0, 'reports' => array() );
$mem   = array();
$get   = function ( $k ) use ( &$mem ) { return isset( $mem[ $k ] ) ? $mem[ $k ] : false; };
$set   = function ( $k, $v ) use ( &$mem ) { $mem[ $k ] = $v; };

// Client: request shape.
$seen = null;
$c    = new Client( 'ot_live_x', 'https://example.test/api/v1/', 3, transport( 200, $clean, $seen ) );
$c->lookup( '98765 43210' );
check( 'POST to /lookups', 'POST' === $seen['method'] && 'https://example.test/api/v1/lookups' === $seen['url'] );
check( 'bearer header', 'Bearer ot_live_x' === $seen['headers']['Authorization'] );
check( 'json body', array( 'phone' => '98765 43210' ) === json_decode( $seen['payload'], true ) );
check( 'timeout passed', 3 === $seen['timeout'] );
$c->report( '9876543210', 'cod_refusal' );
check( 'report omits empty notes', array( 'phone' => '9876543210', 'reason_code' => 'cod_refusal' ) === json_decode( $seen['payload'], true ) );

// Client: errors.
foreach ( array( 401, 402, 403, 409, 422, 429, 503 ) as $s ) {
	try {
		( new Client( 'k', null, 3, transport( $s, array( 'error' => array( 'code' => 'x', 'message' => 'boom' ) ) ) ) )->lookup( '9876543210' );
		check( "error $s thrown", false );
	} catch ( ApiException $e ) {
		check( "error $s mapped", $e->status === $s && 'boom' === $e->getMessage() && 'x' === $e->error_code );
	}
}
try { ( new Client( '', null, 3, transport( 200, $clean ) ) )->lookup( '9876543210' ); check( 'empty key rejected', false ); } catch ( ApiException $e ) { check( 'empty key rejected', 401 === $e->status ); }

// Checker: should_check.
$ck = new Checker( new Client( 'k', null, 3, transport( 200, $clean ) ), array( 'only_cod' => true ), $get, $set );
check( 'COD with phone qualifies', $ck->should_check( new FakeOrder( '9876543210', 'cod' ) ) );
check( 'prepaid skipped when only_cod', ! $ck->should_check( new FakeOrder( '9876543210', 'razorpay' ) ) );
check( 'no phone skipped', ! $ck->should_check( new FakeOrder( '  ', 'cod' ) ) );
$done = new FakeOrder(); $done->meta[ Checker::META_CHECKED ] = 'x';
check( 'already checked skipped', ! $ck->should_check( $done ) );
$all = new Checker( new Client( 'k', null, 3, transport( 200, $clean ) ), array( 'only_cod' => false ), $get, $set );
$dflt = new Checker( new Client( 'k', null, 3, transport( 200, $clean ) ), array(), $get, $set );
check( 'prepaid qualifies by default (only_cod is off unless the merchant turns it on)', $dflt->should_check( new FakeOrder( '9876543210', 'razorpay' ) ) );
$odd = new Client( 'k', null, 3, transport( 422, array( 'error' => array( 'code' => 'x', 'message' => "Don't use <b>this</b> & that" ) ) ) );
try { $odd->lookup( '9876543210' ); check( 'an API error is thrown', false ); } catch ( ApiException $e ) {
	check( 'the exception message is stored escaped', false === strpos( $e->getMessage(), '<b>' ) );
	check( 'text() gives back the plain message once, not double-escaped', "Don't use <b>this</b> & that" === $e->text() );
}
check( 'prepaid qualifies when only_cod off', $all->should_check( new FakeOrder( '9876543210', 'razorpay' ) ) );

// Checker: reported -> note only (default).
$o  = new FakeOrder();
$ck = new Checker( new Client( 'k', null, 3, transport( 200, $reported ) ), array(), $get, $set );
check( 'reported status', 'reported' === $ck->check_order( $o ) );
check( 'count stored', 2 === $o->meta[ Checker::META_COUNT ] );
check( 'checked_at stored', ! empty( $o->meta[ Checker::META_CHECKED ] ) );
check( 'one order note', 1 === count( $o->notes ) );
check( 'note lists reasons', false !== strpos( $o->notes[0], 'Refused a cash-on-delivery order' ) && false !== strpos( $o->notes[0], 'Asked someone for an OTP' ) );
check( 'note strips html', false === strpos( $o->notes[0], '<b>' ) );
check( 'note carries the disclaimer', false !== strpos( $o->notes[0], 'unverified observations' ) );
check( 'status unchanged by default', 'processing' === $o->status );

// Checker: hold_on_report.
$o  = new FakeOrder();
$ck = new Checker( new Client( 'k', null, 3, transport( 200, $reported ) ), array( 'hold_on_report' => true ), $get, $set );
$ck->check_order( $o );
check( 'put on hold', 'on-hold' === $o->status );
$shipped = new FakeOrder(); $shipped->status = 'completed';
$ck->check_order( $shipped, true );
check( 'completed orders are not put on hold', 'completed' === $shipped->status );

// Checker: clean. (Each scenario starts with an empty cache, or an earlier result for the same number would be served.)
$mem = array();
$o   = new FakeOrder();
$ck = new Checker( new Client( 'k', null, 3, transport( 200, $clean ) ), array(), $get, $set );
check( 'clean status', 'clean' === $ck->check_order( $o ) );

// Checker: cache avoids a second lookup.
$mem   = array();
$calls = 0;
$counting = function () use ( &$calls, $reported ) { ++$calls; return array( 200, json_encode( $reported ) ); };
$ck = new Checker( new Client( 'k', null, 3, $counting ), array(), $get, $set );
$ck->check_order( new FakeOrder( '98765 43210' ) );
$ck->check_order( new FakeOrder( '+91 9876543210' ) );
$ck->check_order( new FakeOrder( '98765-43210' ) );
check( 'one lookup serves every format of the same number', 1 === $calls );

// Checker: failures fail open.
$mem = array();
$o   = new FakeOrder();
$ck = new Checker( new Client( 'k', null, 3, transport( 503, array() ) ), array(), $get, $set );
check( 'outage fails open', 'error' === $ck->check_order( $o ) && array() === $o->notes && empty( $o->meta[ Checker::META_CHECKED ] ) );
$mem = array();
$o   = new FakeOrder();
$ck = new Checker( new Client( 'k', null, 3, transport( 402, array( 'error' => array( 'code' => 'no_checks_remaining', 'message' => 'x' ) ) ) ), array(), $get, $set );
$ck->check_order( $o );
check( 'out of checks leaves a note, order unchanged', 1 === count( $o->notes ) && false !== strpos( $o->notes[0], 'no checks are left' ) && 'processing' === $o->status );
$o  = new FakeOrder( '' , 'cod' );
check( 'no phone is recorded as skipped', 'skipped' === ( new Checker( new Client( 'k', null, 3, transport( 200, $clean ) ), array(), $get, $set ) )->check_order( $o ) );

// Reasons mirror the API.
check( 'fallback reasons include impersonation codes', isset( Reasons::all()['otp_fraud'], Reasons::all()['bank_impersonation'] ) && 16 === count( Reasons::all() ) );
check( 'fallback reasons include the newer codes', isset( Reasons::all()['promo_abuse'], Reasons::all()['document_mismatch'], Reasons::all()['third_party_payment_fraud'] ) );


// Live reason list: the API's list wins, a malformed one falls back, and groups follow the live data.
$live = array(
	array( 'code' => 'cod_refusal', 'group' => 'Orders', 'label' => 'Refused COD', 'use_when' => 'u' ),
	array( 'code' => 'brand_new_code', 'group' => 'Newer', 'label' => 'A code added after this plugin shipped' ),
	array( 'code' => 'broken' ),
	'not an entry',
);
check( 'live list replaces the shipped one', array( 'cod_refusal' => 'Refused COD', 'brand_new_code' => 'A code added after this plugin shipped' ) === Reasons::all( $live ) );
check( 'live groups follow the API', array( 'Orders', 'Newer' ) === array_keys( Reasons::groups( $live ) ) );
check( 'empty live list falls back', 16 === count( Reasons::all( array() ) ) && 16 === count( Reasons::all( null ) ) );
check( 'a list with no valid entry falls back', 16 === count( Reasons::all( array( array( 'code' => 'x' ), 'y' ) ) ) );

// Client: reason_codes and the optional report fields.
$seen = null;
$c    = new Client( 'ot_live_x', 'https://example.test/api/v1', 3, transport( 200, array( 'reason_codes' => $live ), $seen ) );
check( 'reason_codes returns the list', 4 === count( $c->reason_codes() ) && 'GET' === $seen['method'] && 'https://example.test/api/v1/reason_codes' === $seen['url'] );
$c = new Client( 'ot_live_x', 'https://example.test/api/v1', 3, transport( 200, array( 'nope' => 1 ), $seen ) );
check( 'reason_codes is empty for an unexpected body', array() === $c->reason_codes() );
$c = new Client( 'ot_live_x', 'https://example.test/api/v1', 3, transport( 201, array( 'id' => 1 ), $seen ) );
$c->report( '9876543210', 'chargeback', 'Disputed on 2 orders', '2026-08-14', 'bank' );
check( 'report sends incident_at and confirmed_by', array( 'phone' => '9876543210', 'reason_code' => 'chargeback', 'notes' => 'Disputed on 2 orders', 'incident_at' => '2026-08-14', 'confirmed_by' => 'bank' ) === json_decode( $seen['payload'], true ) );
$c->report( '9876543210', 'chargeback' );
check( 'report omits empty optional fields', array( 'phone' => '9876543210', 'reason_code' => 'chargeback' ) === json_decode( $seen['payload'], true ) );

// Order note: dates, confirmation and own report.
$note = Checker::build_note( array( 'report_count' => 1, 'reports' => array( array( 'reason' => 'Disputed a payment (chargeback)', 'notes' => 'Two orders', 'incident_at' => '2026-08-14', 'reported_at' => '2026-10-01', 'confirmed_by' => 'payment_gateway' ) ) ) );
check( 'note shows incident date, report date and who confirmed', false !== strpos( $note, '(happened 2026-08-14; reported 2026-10-01; the reporter says it was confirmed by a payment gateway)' ) );
$note = Checker::build_note( array( 'report_count' => 1, 'reports' => array( array( 'reason' => 'x', 'reported_at' => '2026-10-01', 'confirmed_by' => 'my cousin' ) ) ) );
check( 'an unknown confirmed_by is not shown', false === strpos( $note, 'confirmed by' ) && false !== strpos( $note, '(reported 2026-10-01)' ) );
$o = new FakeOrder();
( new Checker( new Client( 'k', null, 3, transport( 200, array( 'phone_last4' => '3210', 'report_count' => 0, 'own_report' => true, 'reports' => array() ) ) ), array(), $get, $set ) )->check_order( $o );
check( 'own report is mentioned when nobody else reported', false !== strpos( implode( ' ', $o->notes ), 'You have shared an experience with it yourself' ) );

echo "\n$total checks, $failures failed\n";
exit( $failures ? 1 : 0 );
