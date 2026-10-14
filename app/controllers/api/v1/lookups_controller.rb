module Api
  module V1
    class LookupsController < BaseController
      # A number (`phone`) or its SHA-256 (`phone_sha256` with `phone_length`): see PhoneNormalizer.
      def create
        result = LookupService.call(current_merchant, [{ phone: params[:phone], phone_sha256: params[:phone_sha256], phone_length: params[:phone_length] }]).first
        render json: result.merge(notice: OpenTrust::LOOKUP_NOTICE, checks_remaining: checks_remaining)
      end

      # `phones` (numbers) or `phone_sha256s` (SHA-256 values, with one `phone_length` for the whole list), 1 to 100.
      def batch
        phones, hashes = params[:phones], params[:phone_sha256s]
        return render_error(422, "invalid_phones", "send phones or phone_sha256s, not both") if phones && hashes

        list = phones || hashes
        unless list.is_a?(Array) && list.size.between?(1, LookupService::MAX_BATCH)
          return render_error(422, "invalid_phones", "phones (or phone_sha256s) must be an array of 1-#{LookupService::MAX_BATCH}")
        end

        items = hashes ? list.map { |h| { phone_sha256: h, phone_length: params[:phone_length] } } : list
        results = LookupService.call(current_merchant, items)
        render json: { results: results, notice: OpenTrust::LOOKUP_NOTICE, checks_remaining: checks_remaining }
      end
    end
  end
end
