class MerchantApproval
  def self.approve!(merchant, admin)
    merchant.with_lock do
      raise "already approved" if merchant.approved?
      raise "email not verified" unless merchant.merchant_user&.email_verified?
      merchant.update!(status: "approved", approved_at: Time.current, approved_by_id: admin.id, rejection_reason: nil)
      Checks::Ledger.apply!(merchant, OpenTrust::FREE_CHECKS, reason: "signup_grant")
    end
    AuditLog.record(admin, "merchant.approve", merchant)
    MerchantMailer.approved(merchant).deliver_later
  end

  def self.reject!(merchant, admin, reason)
    merchant.update!(status: "rejected", rejection_reason: reason)
    AuditLog.record(admin, "merchant.reject", merchant, reason: reason)
    MerchantMailer.rejected(merchant).deliver_later
  end
end
