module Api
  module V1
    # A development aid, not for production traffic: it takes a number, so it defeats the point of sending hashes. Use it with
    # test numbers to confirm your code produces the same SHA-256 we do. It costs no checks.
    class PhoneHashController < BaseController
      def check
        e164 = PhoneNormalizer.e164(params.require(:phone))
        expected = PhoneNormalizer.sha256(e164)
        theirs = params[:phone_sha256].presence
        render json: { phone: e164, phone_sha256: expected, phone_length: e164.length, match: theirs ? theirs.to_s.strip.downcase == expected : nil,
                       format: "SHA-256, as 64 lowercase hex characters, of +91 followed by ten digits (13 characters); send that length as phone_length" }
      end
    end
  end
end
