# Transactional email via Resend (https://resend.com). The sending domain must be verified in Resend
# (SPF + DKIM) before codes will reliably reach inboxes.
Resend.api_key = ENV["RESEND_API_KEY"]
Rails.logger.warn("RESEND_API_KEY is not set; emails will not be delivered") if Rails.env.production? && ENV["RESEND_API_KEY"].blank?
