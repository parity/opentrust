class ReportService
  class Duplicate < StandardError; end

  def self.call(merchant, phone:, reason_code:, notes: nil, incident_at: nil)
    p = PhoneNormalizer.call(phone)
    report = FraudReport.new(merchant: merchant, phone_hash: p[:hash], phone_ciphertext: p[:e164], phone_last4: p[:last4],
                             reason_code: reason_code, notes: notes, incident_at: incident_at)
    report.save!
    report
  rescue ActiveRecord::RecordNotUnique
    raise Duplicate, "you have already reported this number"
  end
end
