# Normalises Indian mobile numbers to E.164 and turns them into the key we store and match on.
#
# The key is HMAC(secret, sha256(e164)). The SHA-256 step is the part a client can do itself, so a merchant may send us the
# SHA-256 of the number instead of the number (see PhoneNormalizer.from_sha256). The HMAC step uses a secret only we hold, so a
# leaked database cannot be brute-forced. A number sent in clear and the same number sent as its SHA-256 end up on the same key.
class PhoneNormalizer
  class Invalid < StandardError; end

  # What a client declares with a hash: the length of the text it hashed. "+919876543210" is 13 characters, so this catches the common
  # mistakes (10 = just the digits, 11 = a leading 0, 12 = 91 without the +) before they turn into silent misses.
  HASHED_LENGTH = 13
  LENGTH_HINTS = {
    10 => "that looks like just the ten digits: put +91 in front of them before hashing",
    11 => "that looks like a leading 0 plus the ten digits: drop the 0 and put +91 in front",
    12 => "that looks like 91 plus the ten digits: put a + in front (+91 and the ten digits)"
  }.freeze

  SHA256_FORMAT = "phone_sha256 must be the lowercase hex SHA-256 (64 characters) of +91 followed by ten digits, for example +919876543210".freeze

  def self.e164(raw)
    digits = raw.to_s.gsub(/\D/, "")
    digits = digits.delete_prefix("91") if digits.length == 12 && digits.start_with?("91")
    digits = digits.delete_prefix("0") if digits.length == 11 && digits.start_with?("0")
    raise Invalid, "not a valid Indian mobile number" unless digits.match?(/\A[6-9]\d{9}\z/)
    "+91#{digits}"
  end

  # What a client computes: 64 lowercase hex characters.
  def self.sha256(e164) = Digest::SHA256.hexdigest(e164)

  # What we store and look up by. Takes the SHA-256 hex, never the number.
  def self.hash(sha256_hex) = OpenSSL::HMAC.hexdigest("SHA256", OpenTrust.phone_pepper, sha256_hex)

  def self.call(raw)
    e = e164(raw)
    s = sha256(e)
    { e164: e, sha256: s, hash: hash(s), last4: e[-4..] }
  end

  # A number the client already hashed. We never see the number, so there is no e164, and `last4` is only what the client says.
  def self.from_sha256(hex, last4: nil, length: nil)
    s = hex.to_s.strip.downcase
    raise Invalid, SHA256_FORMAT unless s.match?(/\A[0-9a-f]{64}\z/)
    check_length!(length)
    raise Invalid, "phone_last4 must be four digits" unless last4.nil? || last4.to_s.match?(/\A\d{4}\z/)
    { e164: nil, sha256: s, hash: hash(s), last4: last4&.to_s }
  end

  # The client says how long the text was that it hashed. It must be exactly +91 and the ten digits.
  def self.check_length!(length)
    if length.blank?
      raise Invalid, "phone_length is required with phone_sha256: the length of the text you hashed, which is #{HASHED_LENGTH} (+91 and ten digits, for example +919876543210)"
    end
    n = Integer(length.to_s, 10, exception: false)
    return if n == HASHED_LENGTH

    hint = LENGTH_HINTS[n] || "the text you hash must be +91 followed by ten digits"
    raise Invalid, "phone_length must be #{HASHED_LENGTH}, you sent #{length.to_s.first(10)}: #{hint}"
  end

  # One entry of an API request: a number (String or { phone: }) or an already-hashed one ({ phone_sha256:, phone_last4: }).
  def self.resolve(item)
    return call(item) if item.is_a?(String)

    phone = item[:phone].presence
    hashed = item[:phone_sha256].presence
    raise Invalid, "send phone or phone_sha256, not both" if phone && hashed
    raise Invalid, "send phone or phone_sha256" unless phone || hashed
    phone ? call(phone) : from_sha256(hashed, last4: item[:phone_last4].presence, length: item[:phone_length])
  end
end
