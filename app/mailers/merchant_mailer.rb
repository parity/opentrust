# Each email has an HTML and a plain-text version (app/views/merchant_mailer). Previews: /rails/mailers in development.
class MerchantMailer < ApplicationMailer
  def received(merchant)
    @merchant = merchant
    mail(to: merchant.contact_email, subject: "OpenTrust: we received your registration")
  end

  def verification_code(user, code)
    @code = code
    @expires_in = EmailOtp::TTL.inspect
    mail(to: user.email, subject: "Your OpenTrust verification code: #{code}")
  end

  def approved(merchant)
    @merchant = merchant
    mail(to: merchant.contact_email, subject: "OpenTrust: you're approved")
  end

  def rejected(merchant)
    @merchant = merchant
    mail(to: merchant.contact_email, subject: "OpenTrust: registration update")
  end
end
