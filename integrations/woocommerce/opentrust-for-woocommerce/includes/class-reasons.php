<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

/** Reason codes accepted by the OpenTrust API, with plain descriptions of what a merchant observed. */
class Reasons {
	public static function groups() {
		return array(
			'Orders and payments'           => array(
				'cod_refusal'        => 'Refused a cash-on-delivery order',
				'fake_order'         => 'Placed an order that appeared fake',
				'return_abuse'       => 'Repeated return or refund abuse',
				'chargeback'         => 'Disputed a payment (chargeback)',
				'fake_payment_proof' => "Shared payment proof that didn't check out",
			),
			'Impersonation and phone calls' => array(
				'otp_fraud'              => 'Asked someone for an OTP',
				'bank_impersonation'     => 'Posed as a bank or financial institution',
				'merchant_impersonation' => 'Posed as our business or support',
				'phishing_link'          => 'Sent a suspicious payment or login link',
				'kyc_scam'               => 'Posed as a KYC or verification agent',
				'refund_scam'            => 'Made a suspicious refund request',
			),
			'Other'                         => array(
				'identity_fraud' => "Used someone else's identity details",
				'other'          => 'Other',
			),
		);
	}

	public static function all() {
		$all = array();
		foreach ( self::groups() as $codes ) {
			$all = array_merge( $all, $codes );
		}
		return $all;
	}
}
