# Deletes data that has outlived the retention periods stated in the Privacy Policy.
# Reports on legal hold are kept. Run daily: `bin/rails opentrust:purge_expired`.
class RetentionPurge
  REPORT_YEARS = 5   # reports are deleted this long after submission
  REMOVED_DAYS = 90  # reports an admin removed, or a merchant withdrew, are deleted this long after
  AUDIT_YEARS = 3    # admin audit logs

  def self.call(now: Time.current)
    kept = FraudReport.where(legal_hold: false)
    {
      expired_reports: kept.where(created_at: ...(now - REPORT_YEARS.years)).delete_all,
      removed_reports: kept.where(status: %w[removed withdrawn], updated_at: ...(now - REMOVED_DAYS.days)).delete_all,
      audit_logs: AuditLog.where(created_at: ...(now - AUDIT_YEARS.years)).delete_all
    }
  end
end
