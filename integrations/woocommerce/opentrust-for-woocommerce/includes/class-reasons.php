<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

/**
 * The reason codes a merchant can choose. The plugin asks the OpenTrust API for the current list (so new codes appear without
 * a plugin update) and falls back to the list shipped here when the API cannot be reached.
 */
class Reasons {
	/** The list shipped with the plugin. */
	public static function fallback() {
		$rows = array(
			array( 'cod_refusal', 'Orders and returns', 'Refused a cash-on-delivery order' ),
			array( 'fake_order', 'Orders and returns', 'Placed an order that appeared fake' ),
			array( 'return_abuse', 'Orders and returns', 'Repeated return or refund abuse' ),
			array( 'chargeback', 'Payments', 'Disputed a payment (chargeback)' ),
			array( 'fake_payment_proof', 'Payments', "Shared payment proof that didn't check out" ),
			array( 'third_party_payment_fraud', 'Payments', "Paid from someone else's card, bank account or wallet" ),
			array( 'identity_fraud', 'Accounts and identity', "Used someone else's identity details" ),
			array( 'document_mismatch', 'Accounts and identity', "Submitted documents that didn't match" ),
			array( 'promo_abuse', 'Offers and programs', 'Abused offers, cashback or referrals' ),
			array( 'otp_fraud', 'Impersonation and phone calls', 'Asked someone for an OTP' ),
			array( 'bank_impersonation', 'Impersonation and phone calls', 'Posed as a bank or financial institution' ),
			array( 'merchant_impersonation', 'Impersonation and phone calls', 'Posed as our business or support' ),
			array( 'phishing_link', 'Impersonation and phone calls', 'Sent a suspicious payment or login link' ),
			array( 'kyc_scam', 'Impersonation and phone calls', 'Posed as a KYC or verification agent' ),
			array( 'refund_scam', 'Impersonation and phone calls', 'Made a suspicious refund request' ),
			array( 'other', 'Other', 'Other' ),
		);
		$out  = array();
		foreach ( $rows as $r ) {
			$out[] = array( 'code' => $r[0], 'group' => $r[1], 'label' => $r[2], 'use_when' => '' );
		}
		return $out;
	}

	/** Valid entries from the API's list, or the shipped list when the live one is missing or malformed. */
	public static function entries( $live = null ) {
		$clean = array();
		foreach ( (array) $live as $e ) {
			if ( is_array( $e ) && ! empty( $e['code'] ) && ! empty( $e['label'] ) && ! empty( $e['group'] ) ) {
				$clean[] = array(
					'code'     => (string) $e['code'],
					'group'    => (string) $e['group'],
					'label'    => (string) $e['label'],
					'use_when' => isset( $e['use_when'] ) ? (string) $e['use_when'] : '',
				);
			}
		}
		return $clean ? $clean : self::fallback();
	}

	/** group => ( code => label ) */
	public static function groups( $live = null ) {
		$groups = array();
		foreach ( self::entries( $live ) as $e ) {
			$groups[ $e['group'] ][ $e['code'] ] = $e['label'];
		}
		return $groups;
	}

	/** code => label */
	public static function all( $live = null ) {
		$all = array();
		foreach ( self::entries( $live ) as $e ) {
			$all[ $e['code'] ] = $e['label'];
		}
		return $all;
	}
}
