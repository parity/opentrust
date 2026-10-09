module Api
  module V1
    class ReportsController < BaseController
      def create
        report = ReportService.call(current_merchant, phone: params.require(:phone), reason_code: params.require(:reason_code),
                                    notes: params[:notes], incident_at: params[:incident_at])
        render json: { id: report.id, phone_last4: report.phone_last4, status: "recorded" }, status: :created
      end
    end
  end
end
