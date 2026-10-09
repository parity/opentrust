module Api
  module V1
    class MeController < BaseController
      def show
        m = current_merchant
        render json: { merchant: m.business_name, checks_remaining: m.checks_remaining,
                       reports_submitted: m.fraud_reports.active.count }
      end
    end
  end
end
