module Portal
  class ReportsController < BaseController
    def index = (@reports = current_merchant.fraud_reports.order(id: :desc).limit(200))
    def new; end

    def create
      unless params[:confirm_first_hand] == "1"
        flash.now[:alert] = "Please confirm the report is based on your own experience."
        return render :new, status: :unprocessable_entity
      end
      ReportService.call(current_merchant, phone: params[:phone], reason_code: params[:reason_code], notes: params[:notes].presence,
                           confirmed_by: params[:confirmed_by].presence, evidence_ref: params[:evidence_ref].presence)
      redirect_to portal_reports_path, notice: "Thanks. Your report has been recorded."
    rescue PhoneNormalizer::Invalid, ReportService::Duplicate, ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      render :new, status: :unprocessable_entity
    end
  end
end
