# Normalises Indian mobile numbers to E.164 and hashes them for lookup.
class PhoneNormalizer
  class Invalid < StandardError; end

  def self.e164(raw)
    digits = raw.to_s.gsub(/\D/, "")
    digits = digits.delete_prefix("91") if digits.length == 12 && digits.start_with?("91")
    digits = digits.delete_prefix("0") if digits.length == 11 && digits.start_with?("0")
    raise Invalid, "not a valid Indian mobile number" unless digits.match?(/\A[6-9]\d{9}\z/)
    "+91#{digits}"
  end

  def self.hash(e164) = OpenSSL::HMAC.hexdigest("SHA256", OpenTrust.phone_pepper, e164)

  def self.call(raw)
    e = e164(raw)
    { e164: e, hash: hash(e), last4: e[-4..] }
  end
end
