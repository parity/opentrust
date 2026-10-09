module Admin
  class ReportsController < BaseController
    def index = (@reports = FraudReport.includes(:merchant).order(id: :desc).limit(200))

    def remove
      report = FraudReport.find(params[:id])
      report.update!(status: "removed") unless report.status == "removed"
      AuditLog.record(current_admin, "report.remove", report)
      redirect_to admin_reports_path, notice: "Report removed"
    end
  end
end
