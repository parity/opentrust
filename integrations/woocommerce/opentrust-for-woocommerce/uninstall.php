<?php
defined( 'WP_UNINSTALL_PLUGIN' ) || exit;
delete_option( 'opentrust_wc_settings' );
delete_transient( 'opentrust_wc_status' );
