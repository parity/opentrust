class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "OpenTrust <noreply@opentrust.in>") }
  layout "mailer"
  helper MailerHelper
end
