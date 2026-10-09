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

	public function report( $phone, $reason_code, $notes = null ) {
		$payload = array( 'phone' => $phone, 'reason_code' => $reason_code );
		if ( null !== $notes && '' !== $notes ) {
			$payload['notes'] = $notes;
		}
		return $this->request( 'POST', '/reports', $payload );
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
			isset( $err['message'] ) ? $err['message'] : 'OpenTrust returned HTTP ' . $status,
			$status,
			isset( $err['code'] ) ? $err['code'] : ''
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
			throw new ApiException( $res->get_error_message(), 0, 'connection_error' );
		}
		return array( (int) wp_remote_retrieve_response_code( $res ), wp_remote_retrieve_body( $res ) );
	}
}
