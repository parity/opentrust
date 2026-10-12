module Api
  module V1
    # The codes `reason_code` accepts, with labels and descriptions, so clients don't have to hardcode them.
    class ReasonCodesController < BaseController
      def index = render(json: { reason_codes: ReasonCatalog.to_api })
    end
  end
end
