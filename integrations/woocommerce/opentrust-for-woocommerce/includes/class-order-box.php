<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

/** "OpenTrust" box on the order screen: see the result, check again, or share an experience. */
class OrderBox {
	/** @var int[] Orders whose box was rendered on this request; each needs its forms printed in the footer. */
	private static $form_orders = array();

	public static function hooks() {
		add_action( 'add_meta_boxes', array( __CLASS__, 'add' ) );
		add_action( 'admin_post_opentrust_wc_check', array( __CLASS__, 'handle_check' ) );
		add_action( 'admin_post_opentrust_wc_report', array( __CLASS__, 'handle_report' ) );
		add_action( 'admin_notices', array( __CLASS__, 'notices' ) );
		add_action( 'admin_footer', array( __CLASS__, 'print_forms' ) );
	}

	public static function add() {
		$screen = function_exists( 'wc_get_page_screen_id' ) ? wc_get_page_screen_id( 'shop-order' ) : 'shop_order';
		add_meta_box( 'opentrust_wc', 'OpenTrust', array( __CLASS__, 'render' ), $screen, 'side', 'default' );
	}

	public static function render( $post_or_order ) {
		$order = wc_get_order( $post_or_order instanceof \WP_Post ? $post_or_order->ID : $post_or_order );
		if ( ! $order ) {
			return;
		}
		$status = $order->get_meta( Checker::META_STATUS );
		$count  = (int) $order->get_meta( Checker::META_COUNT );
		$labels = array(
			'clean'    => 'No reports found',
			'reported' => sprintf( 'Reported by %d %s', $count, 1 === $count ? 'merchant' : 'merchants' ),
			'skipped'  => 'Not checked',
			'error'    => 'Could not check',
		);
		echo '<p><strong>' . esc_html( isset( $labels[ $status ] ) ? $labels[ $status ] : 'Not checked yet' ) . '</strong></p>';
		if ( 'reported' === $status ) {
			echo '<p class="description">See the order notes for what was reported. These are unverified observations, not a finding about the customer.</p>';
		}

		// WordPress wraps the whole order screen in its own <form>, and forms cannot be nested. So the real forms are
		// printed in the page footer (print_forms) and the inputs and buttons below attach to them with the `form` attribute.
		$id          = (int) $order->get_id();
		$check_form  = 'opentrust-check-' . $id;
		$share_form  = 'opentrust-share-' . $id;
		self::$form_orders[] = $id;

		echo '<input type="hidden" form="' . esc_attr( $check_form ) . '" name="order_id" value="' . esc_attr( $id ) . '" />';
		echo '<input type="hidden" form="' . esc_attr( $check_form ) . '" name="_wpnonce" value="' . esc_attr( wp_create_nonce( 'opentrust_wc_check_' . $id ) ) . '" />';
		echo '<p><button type="submit" form="' . esc_attr( $check_form ) . '" class="button">Check now (uses 1 check)</button></p>';

		echo '<details style="margin-top:12px"><summary>Share an experience with this number</summary><div style="margin-top:8px">';
		echo '<input type="hidden" form="' . esc_attr( $share_form ) . '" name="order_id" value="' . esc_attr( $id ) . '" />';
		echo '<input type="hidden" form="' . esc_attr( $share_form ) . '" name="_wpnonce" value="' . esc_attr( wp_create_nonce( 'opentrust_wc_report_' . $id ) ) . '" />';
		$entries = Settings::reason_entries();
		echo '<p><select form="' . esc_attr( $share_form ) . '" name="reason_code" style="width:100%">';
		foreach ( Reasons::groups( $entries ) as $group => $codes ) {
			echo '<optgroup label="' . esc_attr( $group ) . '">';
			foreach ( $codes as $code => $label ) {
				echo '<option value="' . esc_attr( $code ) . '">' . esc_html( $label ) . '</option>';
			}
			echo '</optgroup>';
		}
		echo '</select><br /><small><a href="https://opentrust.in/docs#reasons" target="_blank" rel="noopener noreferrer">When to use each reason</a>. Share the number of the person who did it, never of a possible victim.</small></p>';
		echo '<p><label>When did it happen? (optional)<br /><input type="date" form="' . esc_attr( $share_form ) . '" name="incident_at" max="' . esc_attr( gmdate( 'Y-m-d' ) ) . '" style="width:100%" /></label></p>';
		echo '<p><label>Confirmed by (optional)<br /><select form="' . esc_attr( $share_form ) . '" name="confirmed_by" style="width:100%">';
		foreach ( self::confirmed_by_options() as $value => $label ) {
			echo '<option value="' . esc_attr( $value ) . '">' . esc_html( $label ) . '</option>';
		}
		echo '</select></label><br /><small>Only if they told you so. Other merchants see it as the reporter\'s claim; OpenTrust does not verify it.</small></p>';
		echo '<p><textarea form="' . esc_attr( $share_form ) . '" name="notes" maxlength="500" rows="3" style="width:100%" placeholder="Facts only, e.g. Refused 3 COD orders in March. No names, links or phone numbers."></textarea></p>';
		echo '<p><label><input type="checkbox" form="' . esc_attr( $share_form ) . '" name="first_hand" value="1" required /> This is based on my own store\'s direct experience and is accurate to the best of my knowledge.</label></p>';
		echo '<p><button type="submit" form="' . esc_attr( $share_form ) . '" class="button">Share</button></p>';
		echo '</div></details>';
	}

	/** The actual <form> elements, printed outside WordPress's own order form. */
	public static function print_forms() {
		foreach ( array_unique( self::$form_orders ) as $id ) {
			foreach ( array( 'check' => 'opentrust_wc_check', 'share' => 'opentrust_wc_report' ) as $name => $action ) {
				echo '<form id="opentrust-' . esc_attr( $name ) . '-' . esc_attr( $id ) . '" method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
				echo '<input type="hidden" name="action" value="' . esc_attr( $action ) . '" /></form>';
			}
		}
	}

	public static function handle_check() {
		$order = self::authorise( 'opentrust_wc_check_' );
		$status = ( new Checker( Settings::client(), self::options() ) )->check_order( $order, true );
		self::back( $order, 'Checked: ' . $status . '.' );
	}

	public static function handle_report() {
		$order = self::authorise( 'opentrust_wc_report_' ); // Verifies the nonce and the capability before anything is read.
		// phpcs:disable WordPress.Security.NonceVerification.Missing -- the nonce was verified in self::authorise() above.
		if ( empty( $_POST['first_hand'] ) ) {
			self::back( $order, 'Please confirm the report is based on your own experience.', true );
		}
		$reason = isset( $_POST['reason_code'] ) ? sanitize_key( wp_unslash( $_POST['reason_code'] ) ) : '';
		$notes  = isset( $_POST['notes'] ) ? sanitize_textarea_field( wp_unslash( $_POST['notes'] ) ) : '';
		$all    = Reasons::all( Settings::reason_entries() );
		if ( ! isset( $all[ $reason ] ) ) {
			self::back( $order, 'Please choose what happened.', true );
		}
		if ( 'other' === $reason && strlen( trim( $notes ) ) < 10 ) {
			self::back( $order, 'Please add a short note (at least 10 characters) when the reason is Other.', true );
		}
		$incident     = isset( $_POST['incident_at'] ) ? sanitize_text_field( wp_unslash( $_POST['incident_at'] ) ) : '';
		$incident     = preg_match( '/^\d{4}-\d{2}-\d{2}$/', $incident ) ? $incident : '';
		$confirmed_by = isset( $_POST['confirmed_by'] ) ? sanitize_key( wp_unslash( $_POST['confirmed_by'] ) ) : '';
		$confirmed_by = isset( self::confirmed_by_options()[ $confirmed_by ] ) ? $confirmed_by : '';
		try {
			Settings::client( 8 )->report( $order->get_billing_phone(), $reason, $notes, $incident, $confirmed_by );
			$order->add_order_note( 'OpenTrust: you shared an experience with this number (' . $all[ $reason ] . ').' );
			self::back( $order, 'Thanks. Your report has been recorded.' );
		} catch ( ApiException $e ) {
			self::back( $order, 409 === $e->status ? 'You have already shared this number.' : $e->text(), true );
		}
		// phpcs:enable WordPress.Security.NonceVerification.Missing
	}

	public static function notices() {
		$key = 'opentrust_wc_notice_' . get_current_user_id();
		$msg = get_transient( $key );
		if ( $msg ) {
			delete_transient( $key );
			printf( '<div class="notice notice-%s is-dismissible"><p>%s</p></div>', ! empty( $msg['error'] ) ? 'error' : 'success', esc_html( $msg['text'] ) );
		}
	}

	private static function authorise( $nonce_prefix ) {
		$order_id = isset( $_POST['order_id'] ) ? absint( $_POST['order_id'] ) : 0;
		check_admin_referer( $nonce_prefix . $order_id );
		if ( ! current_user_can( 'edit_shop_orders' ) ) {
			wp_die( 'You are not allowed to do that.', 403 );
		}
		$order = wc_get_order( $order_id );
		if ( ! $order ) {
			wp_die( 'Order not found.', 404 );
		}
		return $order;
	}

	private static function back( $order, $text, $error = false ) {
		set_transient( 'opentrust_wc_notice_' . get_current_user_id(), array( 'text' => $text, 'error' => $error ), 60 );
		wp_safe_redirect( $order->get_edit_order_url() );
		exit;
	}

	/** value => label. The empty value means nobody else confirmed it. */
	public static function confirmed_by_options() {
		return array(
			''                => 'Not confirmed by anyone else',
			'bank'            => 'A bank',
			'payment_gateway' => 'A payment gateway',
			'law_enforcement' => 'Law enforcement or a cyber cell',
		);
	}

	public static function options() {
		$o = Settings::get();
		return array( 'only_cod' => 'yes' === $o['only_cod'], 'hold_on_report' => 'yes' === $o['hold_on_report'] );
	}
}
