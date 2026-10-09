class MerchantMailer < ApplicationMailer
  def received(merchant) = mail(to: merchant.contact_email, subject: "OpenTrust: we received your registration") { |f| f.text { render plain: "Hi #{merchant.name}, thanks for registering #{merchant.business_name}. We'll review it shortly." } }
  def verification_code(user, code) = mail(to: user.email, subject: "Your OpenTrust verification code: #{code}") { |f| f.text { render plain: "Your OpenTrust verification code is #{code}.\n\nIt expires in #{EmailOtp::TTL.inspect}. If you didn't register on OpenTrust, you can ignore this email." } }
  def approved(merchant) = mail(to: merchant.contact_email, subject: "OpenTrust: you're approved") { |f| f.text { render plain: "Welcome! Your account has #{OpenTrust::FREE_CHECKS} free checks. Log in to create your API key. Need more later? Just write to #{OpenTrust::FEEDBACK_EMAIL}." } }
  def rejected(merchant) = mail(to: merchant.contact_email, subject: "OpenTrust: registration update") { |f| f.text { render plain: "We couldn't approve #{merchant.business_name} yet. Reason: #{merchant.rejection_reason}. Write to #{OpenTrust::FEEDBACK_EMAIL} if you'd like us to take another look." } }
end
