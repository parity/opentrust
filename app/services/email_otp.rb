# Issues and checks the 6-digit code used to verify a merchant's email address.
# Only an HMAC of the code is stored, never the code itself.
class EmailOtp
  TTL = 10.minutes
  MAX_ATTEMPTS = 5
  RESEND_COOLDOWN = 30.seconds
  MAX_SENDS_PER_HOUR = 5

  class TooSoon < StandardError; end
  class TooMany < StandardError; end

  def self.issue!(user)
    now = Time.current
    raise TooSoon, "Please wait a few seconds before asking for another code." if user.otp_last_sent_at && user.otp_last_sent_at > now - RESEND_COOLDOWN

    in_window = user.otp_window_started_at && user.otp_window_started_at > now - 1.hour
    sends = in_window ? user.otp_sends_in_window : 0
    raise TooMany, "Too many codes requested. Please try again in an hour, or write to #{OpenTrust::FEEDBACK_EMAIL}." if sends >= MAX_SENDS_PER_HOUR

    code = format("%06d", SecureRandom.random_number(1_000_000))
    user.update!(otp_digest: digest(user, code), otp_expires_at: now + TTL, otp_attempts: 0, otp_last_sent_at: now,
                 otp_sends_in_window: sends + 1, otp_window_started_at: in_window ? user.otp_window_started_at : now)
    MerchantMailer.verification_code(user, code).deliver_now
    code
  end

  # Returns :ok, :wrong, :expired or :locked.
  def self.verify!(user, submitted)
    return :expired if user.otp_digest.blank? || user.otp_expires_at.nil? || user.otp_expires_at < Time.current
    return :locked if user.otp_attempts >= MAX_ATTEMPTS

    if ActiveSupport::SecurityUtils.secure_compare(user.otp_digest, digest(user, submitted.to_s.strip))
      user.update!(email_verified_at: Time.current, otp_digest: nil, otp_expires_at: nil, otp_attempts: 0)
      :ok
    else
      user.increment!(:otp_attempts)
      user.otp_attempts >= MAX_ATTEMPTS ? :locked : :wrong
    end
  end

  def self.digest(user, code) = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "otp:#{user.id}:#{code}")
end
