<?php
// Test-only: point the plugin at the Rails app on the host, optionally at a dead address to simulate an outage.
add_filter( 'opentrust_wc_base_url', function () { return get_option( 'opentrust_test_base' ) ?: 'http://host.docker.internal:3000/api/v1'; } );
add_filter( 'http_request_host_is_external', '__return_true' );
add_filter( 'http_request_args', function ( $args ) { $args['reject_unsafe_urls'] = false; return $args; } );
