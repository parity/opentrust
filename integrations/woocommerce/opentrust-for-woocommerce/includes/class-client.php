<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

class ApiException extends \Exception {
	/** @var int HTTP status, or 0 for connection problems. */
	public $status;
	/** @var string Machine-readable code from the API, e.g. no_checks_remaining. */
	public $error_code;

	public function __construct( $message, $status = 0, $error_code = '' ) {
		parent::__construct( $message );
		$this->status     = (int) $status;
		$this->error_code = (string) $error_code;
	}

	/**
	 * The message as plain text, for the log or for escaping again on output. The message itself is stored HTML-escaped
	 * (see the throw sites in Client), which is what the WordPress coding standards ask of exception messages.
	 */
	public function text() {
		return wp_specialchars_decode( $this->getMessage(), ENT_QUOTES );
	}
}

/**
 * Minimal OpenTrust API client. The HTTP transport is injectable so it can be tested without WordPress.
 */
class Client {
	const DEFAULT_BASE = 'https://opentrust.in/api/v1';

	private $api_key;
	private $base;
	private $timeout;
	private $transport;

	/**
	 * @param string        $api_key
	 * @param string|null   $base      API base URL (defaults to production).
	 * @param int           $timeout   Seconds.
	 * @param callable|null $transport function( $method, $url, $headers, $body, $timeout ): array( int $status, string $body ).
	 */
	public function __construct( $api_key, $base = null, $timeout = 4, $transport = null ) {
		$this->api_key   = (string) $api_key;
		$this->base      = rtrim( $base ? $base : self::DEFAULT_BASE, '/' );
		$this->timeout   = $timeout;
		$this->transport = $transport ? $transport : array( $this, 'wp_transport' );
	}

	public function lookup( $phone ) {
		return $this->request( 'POST', '/lookups', array( 'phone' => $phone ) );
	}

	/**
	 * Share an experience. $incident_at is a date (YYYY-MM-DD); $confirmed_by is bank, payment_gateway or law_enforcement
	 * (only when they told the merchant it was confirmed). Both are optional.
	 */
	public function report( $phone, $reason_code, $notes = null, $incident_at = null, $confirmed_by = null ) {
		$payload = array( 'phone' => $phone, 'reason_code' => $reason_code );
		if ( null !== $notes && '' !== $notes ) {
			$payload['notes'] = $notes;
		}
		if ( ! empty( $incident_at ) ) {
			$payload['incident_at'] = $incident_at;
		}
		if ( ! empty( $confirmed_by ) ) {
			$payload['confirmed_by'] = $confirmed_by;
		}
		return $this->request( 'POST', '/reports', $payload );
	}

	/** The reason codes, with labels, groups and guidance. Empty when the response is not what we expect. */
	public function reason_codes() {
		$data = $this->request( 'GET', '/reason_codes' );
		return isset( $data['reason_codes'] ) && is_array( $data['reason_codes'] ) ? $data['reason_codes'] : array();
	}

	public function me() {
		return $this->request( 'GET', '/me' );
	}

	private function request( $method, $path, $payload = null ) {
		if ( '' === $this->api_key ) {
			throw new ApiException( 'No OpenTrust API key is set.', 401, 'invalid_api_key' );
		}
		$headers = array(
			'Authorization' => 'Bearer ' . $this->api_key,
			'Accept'        => 'application/json',
			'User-Agent'    => 'opentrust-woocommerce/' . ( defined( 'OPENTRUST_WC_VERSION' ) ? OPENTRUST_WC_VERSION : 'dev' ),
		);
		$body = null;
		if ( null !== $payload ) {
			$headers['Content-Type'] = 'application/json';
			$body                    = json_encode( $payload );
		}

		list( $status, $text ) = call_user_func( $this->transport, $method, $this->base . $path, $headers, $body, $this->timeout );
		$data                  = json_decode( (string) $text, true );
		$data                  = is_array( $data ) ? $data : array();

		if ( $status >= 200 && $status < 300 ) {
			return $data;
		}
		$err = isset( $data['error'] ) && is_array( $data['error'] ) ? $data['error'] : array();
		throw new ApiException(
			esc_html( isset( $err['message'] ) ? $err['message'] : 'OpenTrust returned HTTP ' . (int) $status ),
			(int) $status,
			esc_html( isset( $err['code'] ) ? $err['code'] : '' )
		);
	}

	/** Default transport, built on the WordPress HTTP API. */
	public function wp_transport( $method, $url, $headers, $body, $timeout ) {
		$res = wp_remote_request(
			$url,
			array(
				'method'  => $method,
				'headers' => $headers,
				'body'    => $body,
				'timeout' => $timeout,
			)
		);
		if ( is_wp_error( $res ) ) {
			throw new ApiException( esc_html( $res->get_error_message() ), 0, 'connection_error' );
		}
		return array( (int) wp_remote_retrieve_response_code( $res ), wp_remote_retrieve_body( $res ) );
	}
}
