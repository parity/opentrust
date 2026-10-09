module Admin
  class MerchantsController < BaseController
    before_action :set_merchant, except: :index

    def index
      @status = Merchant::STATUSES.include?(params[:status]) ? params[:status] : "pending"
      @merchants = Merchant.where(status: @status).order(created_at: :desc).limit(200)
    end

    def approve
      return redirect_to(admin_root_path, alert: "This merchant hasn't verified their email yet.") unless @merchant.merchant_user&.email_verified?
      MerchantApproval.approve!(@merchant, current_admin)
      redirect_to admin_root_path, notice: "#{@merchant.business_name} approved (+#{OpenTrust::FREE_CHECKS} checks)"
    end

    def reject
      MerchantApproval.reject!(@merchant, current_admin, params[:reason].presence || "Not eligible")
      redirect_to admin_root_path, notice: "Rejected"
    end

    def suspend
      @merchant.update!(status: "suspended")
      AuditLog.record(current_admin, "merchant.suspend", @merchant)
      redirect_to admin_root_path(status: "approved"), notice: "Suspended"
    end

    # Raise (or lower) a merchant's check allowance, e.g. after they write to us.
    def adjust
      checks = params[:checks].to_i
      return redirect_to(admin_root_path(status: "approved"), alert: "Enter a non-zero number of checks") if checks.zero?
      Checks::Ledger.apply!(@merchant, checks, reason: "admin_adjust", memo: params[:memo].to_s.first(200))
      AuditLog.record(current_admin, "merchant.adjust", @merchant, checks: checks, memo: params[:memo])
      redirect_to admin_root_path(status: "approved"), notice: "Adjusted by #{checks} checks"
    rescue Checks::Ledger::Insufficient
      redirect_to admin_root_path(status: "approved"), alert: "Would make the balance negative"
    end

    private

    def set_merchant = (@merchant = Merchant.find(params[:id]))
  end
end
