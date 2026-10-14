module Admin
  class ReportsController < BaseController
    # This page shows decrypted numbers, so every visit is recorded in the audit log.
    def index
      @reports = FraudReport.includes(:merchant).order(id: :desc).limit(200)
      AuditLog.record(current_admin, "reports.view", nil, { shown: @reports.size })
    end

    def remove
      report = FraudReport.find(params[:id])
      report.update!(status: "removed") unless report.status == "removed"
      AuditLog.record(current_admin, "report.remove", report)
      redirect_to admin_reports_path, notice: "Report removed"
    end
  end
end
