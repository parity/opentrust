require "digest"

module OpenTrust
  # The one place the number format is defined. OpenTrust accepts either a phone number or its SHA-256, and a hash only matches
  # if it is computed exactly like this:
  #
  #   1. keep the digits, drop a leading 91 (12 digits) or 0 (11 digits), leaving 10 digits starting 6, 7, 8 or 9
  #   2. prefix "+91", for example "+919876543210"
  #   3. SHA-256 of that text, as 64 lowercase hex characters
  #
  # A hash that does not match simply finds nothing, so use this helper (and the shared test vectors) rather than hashing by hand.
  module Phone
    HASHED_LENGTH = 13 # +91 and ten digits

    module_function

    # "+91" followed by the ten digits. Raises InvalidPhoneError for anything that is not an Indian mobile number.
    def normalize(raw)
      digits = raw.to_s.gsub(/\D/, "")
      digits = digits[2..-1] if digits.length == 12 && digits.start_with?("91")
      digits = digits[1..-1] if digits.length == 11 && digits.start_with?("0")
      raise InvalidPhoneError, "not a valid Indian mobile number" unless digits.match?(/\A[6-9]\d{9}\z/)

      "+91#{digits}"
    end

    # The 64 lowercase hex characters OpenTrust expects as phone_sha256.
    def sha256(raw)
      Digest::SHA256.hexdigest(normalize(raw))
    end

    # The length of the text that is hashed (13), sent as phone_length. OpenTrust refuses any other value, which catches hashes of a
    # differently written number (10 = just the digits, 11 = leading 0, 12 = 91 without the +).
    def hashed_length(raw)
      normalize(raw).length
    end

    # The last four digits, sent with a hashed report so merchants and admins have something to recognise it by.
    def last4(raw)
      normalize(raw)[-4..-1]
    end
  end

  # Hash a number the way OpenTrust expects. Same as Phone.sha256.
  def self.hash_phone(raw)
    Phone.sha256(raw)
  end
end
