<?php
namespace OpenTrust\WooCommerce;

defined( 'ABSPATH' ) || exit;

/** Settings page under WooCommerce > OpenTrust. */
class Settings {
	const OPTION = 'opentrust_wc_settings';

	public static function defaults() {
		return array( 'api_key' => '', 'only_cod' => 'yes', 'hold_on_report' => 'no' );
	}

	public static function get() {
		$saved = get_option( self::OPTION, array() );
		return array_merge( self::defaults(), is_array( $saved ) ? $saved : array() );
	}

	public static function client( $timeout = 4 ) {
		$base = apply_filters( 'opentrust_wc_base_url', Client::DEFAULT_BASE );
		return new Client( self::get()['api_key'], $base, $timeout );
	}

	public static function hooks() {
		add_action( 'admin_menu', array( __CLASS__, 'menu' ) );
		add_action( 'admin_init', array( __CLASS__, 'register' ) );
	}

	public static function menu() {
		add_submenu_page( 'woocommerce', 'OpenTrust', 'OpenTrust', 'manage_woocommerce', 'opentrust-wc', array( __CLASS__, 'render' ) );
	}

	public static function register() {
		register_setting(
			'opentrust_wc',
			self::OPTION,
			array(
				'type'              => 'array',
				'sanitize_callback' => array( __CLASS__, 'sanitize' ),
				'default'           => self::defaults(),
			)
		);
	}

	public static function sanitize( $input ) {
		$input = is_array( $input ) ? $input : array();
		return array(
			'api_key'        => isset( $input['api_key'] ) ? trim( sanitize_text_field( $input['api_key'] ) ) : '',
			'only_cod'       => empty( $input['only_cod'] ) ? 'no' : 'yes',
			'hold_on_report' => empty( $input['hold_on_report'] ) ? 'no' : 'yes',
		);
	}

	public static function render() {
		if ( ! current_user_can( 'manage_woocommerce' ) ) {
			return;
		}
		$o = self::get();
		?>
		<div class="wrap">
			<h1>OpenTrust</h1>
			<p>Check new orders' phone numbers against experiences shared by other Indian merchants. Reports are unverified observations from individual merchants, not a finding about anyone, so this plugin flags orders for your review and never blocks checkout.</p>
			<?php self::render_status( $o ); ?>
			<form method="post" action="options.php">
				<?php settings_fields( 'opentrust_wc' ); ?>
				<table class="form-table" role="presentation">
					<tr>
						<th scope="row"><label for="opentrust_api_key">API key</label></th>
						<td>
							<input type="password" id="opentrust_api_key" name="<?php echo esc_attr( self::OPTION ); ?>[api_key]" value="<?php echo esc_attr( $o['api_key'] ); ?>" class="regular-text" autocomplete="off" />
							<p class="description">Create one in your <a href="https://opentrust.in/portal/api_keys" target="_blank" rel="noopener noreferrer">OpenTrust dashboard</a>. Don't have an account? <a href="https://opentrust.in/register" target="_blank" rel="noopener noreferrer">Register free</a>.</p>
						</td>
					</tr>
					<tr>
						<th scope="row">Which orders</th>
						<td><label><input type="checkbox" name="<?php echo esc_attr( self::OPTION ); ?>[only_cod]" value="1" <?php checked( 'yes', $o['only_cod'] ); ?> /> Only cash-on-delivery orders <span class="description">(saves your checks, and COD is where most problems happen)</span></label></td>
					</tr>
					<tr>
						<th scope="row">If reports are found</th>
						<td>
							<label><input type="checkbox" name="<?php echo esc_attr( self::OPTION ); ?>[hold_on_report]" value="1" <?php checked( 'yes', $o['hold_on_report'] ); ?> /> Also put the order on hold</label>
							<p class="description">Either way an order note lists what was reported. Putting orders on hold gives you a moment to review them, for example by calling the customer. Orders are never cancelled or blocked.</p>
						</td>
					</tr>
				</table>
				<?php submit_button(); ?>
			</form>
			<h2>What gets sent</h2>
			<p>For each order checked, only the billing phone number is sent to <code>opentrust.in</code> over HTTPS. No names, addresses or order details. Please mention this in your store's privacy policy. See OpenTrust's <a href="https://opentrust.in/privacy" target="_blank" rel="noopener noreferrer">Privacy Policy</a> and <a href="https://opentrust.in/terms" target="_blank" rel="noopener noreferrer">Terms</a>.</p>
		</div>
		<?php
	}

	private static function render_status( $o ) {
		if ( '' === $o['api_key'] ) {
			echo '<div class="notice notice-warning inline"><p>Add your API key below to start checking orders.</p></div>';
			return;
		}
		$status = get_transient( 'opentrust_wc_status' );
		if ( false === $status ) {
			try {
				$me     = self::client( 5 )->me();
				$status = array( 'ok' => true, 'text' => sprintf( 'Connected as %s. %s checks left.', $me['merchant'], number_format_i18n( $me['checks_remaining'] ) ) );
			} catch ( ApiException $e ) {
				$status = array( 'ok' => false, 'text' => 'Could not connect: ' . $e->getMessage() );
			}
			set_transient( 'opentrust_wc_status', $status, 60 );
		}
		printf( '<div class="notice notice-%s inline"><p>%s</p></div>', $status['ok'] ? 'success' : 'error', esc_html( $status['text'] ) );
	}
}
