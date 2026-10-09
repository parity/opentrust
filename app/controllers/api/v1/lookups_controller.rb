module Api
  module V1
    class LookupsController < BaseController
      def create
        result = LookupService.call(current_merchant, [params.require(:phone)]).first
        render json: result.merge(notice: OpenTrust::LOOKUP_NOTICE, checks_remaining: checks_remaining)
      end

      def batch
        phones = params.require(:phones)
        return render_error(422, "invalid_phones", "phones must be an array of 1-#{LookupService::MAX_BATCH}") unless phones.is_a?(Array) && phones.size.between?(1, LookupService::MAX_BATCH)
        results = LookupService.call(current_merchant, phones)
        render json: { results: results, notice: OpenTrust::LOOKUP_NOTICE, checks_remaining: checks_remaining }
      end
    end
  end
end
