class ApplicationMailer < ActionMailer::Base
  # TEMPORARY: paritycube.com is the verified Resend domain. Once opentrust.in is verified in Resend,
  # set MAIL_FROM="OpenTrust <noreply@opentrust.in>" (no code change needed) and drop this default.
  default from: -> { ENV.fetch("MAIL_FROM", "OpenTrust <noreply@opentrust.in>") }
  layout "mailer"
end
