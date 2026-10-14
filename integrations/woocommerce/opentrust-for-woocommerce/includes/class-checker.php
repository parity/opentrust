<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

/**
 * Decides whether to check an order, runs the check, and records the outcome on the order.
 * Only touches the order through a handful of WC_Order methods, so it can be tested with a fake.
 * It never blocks checkout, and every failure leaves the order exactly as it was.
 */
class Checker {
	const META_STATUS  = '_opentrust_status';   // clean | reported | skipped | error
	const META_COUNT   = '_opentrust_report_count';
	const META_CHECKED = '_opentrust_checked_at';
	const CACHE_TTL    = 21600; // 6 hours, so repeat customers don't use extra checks

	private $client;
	private $options;
	private $cache_get;
	private $cache_set;

	/**
	 * @param Client        $client
	 * @param array         $options   only_cod (bool), hold_on_report (bool).
	 * @param callable|null $cache_get function( $key ) => mixed|false
	 * @param callable|null $cache_set function( $key, $value, $ttl )
	 */
	public function __construct( Client $client, array $options = array(), $cache_get = null, $cache_set = null ) {
		$this->client    = $client;
		$this->options   = array_merge( array( 'only_cod' => false, 'hold_on_report' => false ), $options );
		$this->cache_get = $cache_get ? $cache_get : 'get_transient';
		$this->cache_set = $cache_set ? $cache_set : 'set_transient';
	}

	/** Whether this order qualifies for an automatic check. */
	public function should_check( $order ) {
		if ( '' === trim( (string) $order->get_billing_phone() ) ) {
			return false;
		}
		if ( $order->get_meta( self::META_CHECKED ) ) {
			return false; // already checked
		}
		if ( ! empty( $this->options['only_cod'] ) && 'cod' !== $order->get_payment_method() ) {
			return false;
		}
		return true;
	}

	/**
	 * Check the order's billing phone and record the result.
	 *
	 * @param bool $force Ignore the cache and the "already checked" guard (used by the manual button).
	 * @return string The recorded status.
	 */
	public function check_order( $order, $force = false ) {
		$phone = trim( (string) $order->get_billing_phone() );
		if ( '' === $phone ) {
			return $this->record( $order, 'skipped', 0, 'OpenTrust: no phone number on this order, so nothing was checked.' );
		}

		$key    = 'opentrust_' . md5( self::digits( $phone ) );
		$cached = $force ? false : call_user_func( $this->cache_get, $key );

		try {
			$result = is_array( $cached ) ? $cached : $this->client->lookup( $phone );
			if ( ! is_array( $cached ) ) {
				call_user_func( $this->cache_set, $key, $result, self::CACHE_TTL );
			}
		} catch ( ApiException $e ) {
			return $this->handle_failure( $order, $e );
		}

		return $this->apply( $order, $result );
	}

	/** Record a successful lookup on the order. */
	public function apply( $order, array $result ) {
		$count = isset( $result['report_count'] ) ? (int) $result['report_count'] : 0;
		if ( $count < 1 ) {
			$note = 'OpenTrust: no other merchant has noted anything about this number.';
			if ( ! empty( $result['own_report'] ) ) {
				$note .= ' (You have shared an experience with it yourself.)';
			}
			return $this->record( $order, 'clean', 0, $note );
		}

		$status = $this->record( $order, 'reported', $count, self::build_note( $result ) );
		if ( ! empty( $this->options['hold_on_report'] ) && $order->has_status( array( 'pending', 'processing' ) ) ) {
			$order->update_status( 'on-hold', 'OpenTrust: put on hold for review because other merchants have noted experiences with this number.' );
		}
		return $status;
	}

	/** Plain-text order note for a result that has reports. */
	public static function build_note( array $result ) {
		$count = (int) $result['report_count'];
		$lines = array( sprintf( 'OpenTrust: %d %s noted experiences with this number.', $count, 1 === $count ? 'merchant has' : 'merchants have' ) );
		foreach ( (array) ( isset( $result['reports'] ) ? $result['reports'] : array() ) as $r ) {
			$what = ! empty( $r['reason'] ) ? $r['reason'] : ( isset( $r['reason_code'] ) ? $r['reason_code'] : '' );
			$line = '• ' . self::clean( $what );
			if ( ! empty( $r['notes'] ) ) {
				$line .= ': "' . self::clean( $r['notes'] ) . '"';
			}
			$when = array();
			if ( ! empty( $r['incident_at'] ) ) {
				$when[] = 'happened ' . self::clean( $r['incident_at'] );
			}
			if ( ! empty( $r['reported_at'] ) ) {
				$when[] = 'reported ' . self::clean( $r['reported_at'] );
			}
			$sources = array( 'bank' => 'a bank', 'payment_gateway' => 'a payment gateway', 'law_enforcement' => 'law enforcement' );
			if ( ! empty( $r['confirmed_by'] ) && isset( $sources[ $r['confirmed_by'] ] ) ) {
				$when[] = 'the reporter says it was confirmed by ' . $sources[ $r['confirmed_by'] ];
			}
			if ( $when ) {
				$line .= ' (' . implode( '; ', $when ) . ')';
			}
			$lines[] = $line;
		}
		$lines[] = 'These are unverified observations from individual merchants, not a finding about the customer. Please review the order yourself before deciding anything.';
		return implode( "\n", $lines );
	}

	private function handle_failure( $order, ApiException $e ) {
		// Authentication, approval and allowance problems need the store owner's attention; everything else stays quiet.
		$notable = array( 401 => 'the API key is missing or invalid', 402 => 'no checks are left. Write to feedback@opentrust.in and we will raise your limit', 403 => 'the OpenTrust account is not approved' );
		if ( isset( $notable[ $e->status ] ) ) {
			return $this->record( $order, 'error', 0, 'OpenTrust: this order was not checked because ' . $notable[ $e->status ] . '.', false );
		}
		// Timeouts, outages, rate limits: fail open, and leave the order unmarked so a manual check can still run.
		if ( function_exists( 'wc_get_logger' ) ) {
			wc_get_logger()->warning( 'OpenTrust check failed: ' . $e->text(), array( 'source' => 'opentrust' ) );
		}
		return 'error';
	}

	private function record( $order, $status, $count, $note, $mark_checked = true ) {
		$order->update_meta_data( self::META_STATUS, $status );
		$order->update_meta_data( self::META_COUNT, $count );
		if ( $mark_checked ) {
			$order->update_meta_data( self::META_CHECKED, gmdate( 'c' ) );
		}
		$order->save();
		$order->add_order_note( $note ); // private note: never sent to the customer
		return $status;
	}

	/** Last 10 digits, so 98765 43210, 098765 43210 and +91 98765 43210 share one cache entry. */
	private static function digits( $phone ) {
		$d = preg_replace( '/\D+/', '', (string) $phone );
		return strlen( $d ) > 10 ? substr( $d, -10 ) : $d;
	}

	private static function clean( $text ) {
		$text = wp_strip_all_tags( (string) $text );
		return trim( $text );
	}
}
