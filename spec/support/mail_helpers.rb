# The emails are multipart (HTML and plain text), so a message's own `body` is empty: read the plain-text part.
module MailHelpers
  def last_mail_code = ActionMailer::Base.deliveries.last.text_part.body.decoded[/\b\d{6}\b/]
end

RSpec.configure { |config| config.include MailHelpers, type: :request }
