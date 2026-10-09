module Portal
  class DashboardController < BaseController
    skip_before_action :require_approved!
    def show
      return render :pending unless current_merchant.approved?
      @recent = current_merchant.check_ledger_entries.order(id: :desc).limit(10)
      @lookups_30d = current_merchant.check_ledger_entries.where(reason: "lookup", created_at: 30.days.ago..).sum(:delta).abs
      @reports = current_merchant.fraud_reports.active.count
    end
  end
end
