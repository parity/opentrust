module Api
  module V1
    class ReportsController < BaseController
      def create
        report = ReportService.call(current_merchant, phone: params[:phone], phone_sha256: params[:phone_sha256], phone_last4: params[:phone_last4], phone_length: params[:phone_length],
                                    reason_code: params.require(:reason_code),
                                    notes: params[:notes], incident_at: params[:incident_at],
                                    confirmed_by: params[:confirmed_by], evidence_ref: params[:evidence_ref])
        render json: { id: report.id, phone_last4: report.phone_last4, status: "recorded" }, status: :created
      end

      # Up to 100 reports. Always 200 with one result per report, so a bad row never hides the good ones.
      def batch
        items = params.require(:reports)
        unless items.is_a?(Array) && items.size.between?(1, ReportService::MAX_BATCH)
          return render_error(422, "invalid_reports", "reports must be an array of 1-#{ReportService::MAX_BATCH}")
        end

        results = ReportService.batch(current_merchant, items.map { |i| i.respond_to?(:permit) ? i.permit(:phone, :phone_sha256, :phone_last4, :phone_length, :reason_code, :notes, :incident_at, :confirmed_by, :evidence_ref).to_h.symbolize_keys : nil })
        render json: { results: results, summary: results.group_by { |r| r[:status] }.transform_values(&:size).reverse_merge("recorded" => 0, "duplicate" => 0, "invalid" => 0) }
      end

      # Withdraw your own report for a number.
      def destroy
        report = ReportService.withdraw(current_merchant, phone: params[:phone], phone_sha256: params[:phone_sha256], phone_length: params[:phone_length])
        render json: { phone_last4: report.phone_last4, status: "withdrawn" }
      end
    end
  end
end
