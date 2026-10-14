# Files, withdraws and bulk-files reports. One report per merchant per number: a repeat is a Duplicate, except that a
# merchant can file again after withdrawing its own report.
class ReportService
  class Duplicate < StandardError; end
  class NotFound < StandardError; end
  class InvalidIncidentDate < StandardError; end

  MAX_BATCH = 100
  ALREADY_REPORTED = "you have already reported this number".freeze
  ALREADY_REMOVED = "your report for this number was removed by OpenTrust and can't be filed again".freeze

  # Send `phone` (a number) or `phone_sha256` with `phone_last4` (the SHA-256 of the number, and its last four digits for display).
  def self.call(merchant, reason_code:, phone: nil, phone_sha256: nil, phone_last4: nil, phone_length: nil, notes: nil, incident_at: nil, confirmed_by: nil, evidence_ref: nil)
    p = resolve(phone, phone_sha256, phone_last4, phone_length)
    incident = parse_incident_at(incident_at)
    existing = merchant.fraud_reports.find_by(phone_hash: p[:hash])
    return refile!(existing, p, reason_code, notes, incident, confirmed_by.presence, evidence_ref.presence) if existing

    report = FraudReport.new(merchant: merchant, phone_hash: p[:hash], phone_ciphertext: p[:e164], phone_last4: p[:last4],
                             reason_code: reason_code, notes: notes, incident_at: incident,
                             confirmed_by: confirmed_by.presence, evidence_ref: evidence_ref.presence)
    report.save!
    report
  rescue ActiveRecord::RecordNotUnique
    raise Duplicate, ALREADY_REPORTED
  end

  # The merchant takes back its own report. It stops appearing in lookups at once and is deleted after the removal period.
  def self.withdraw(merchant, phone: nil, phone_sha256: nil, phone_length: nil)
    p = resolve(phone, phone_sha256, nil, phone_length, last4_required: false)
    report = merchant.fraud_reports.active.find_by(phone_hash: p[:hash]) or raise NotFound, "you have no active report for this number"
    report.update!(status: "withdrawn")
    report
  end

  # Up to MAX_BATCH reports, each filed on its own: one bad row never blocks the rest. Returns one result per input, in order.
  def self.batch(merchant, items)
    items.each_with_index.map do |item, index|
      begin
        raise ActiveRecord::RecordInvalid, FraudReport.new unless item.respond_to?(:key?)

        report = call(merchant, phone: item[:phone], phone_sha256: item[:phone_sha256], phone_last4: item[:phone_last4], phone_length: item[:phone_length], reason_code: item[:reason_code], notes: item[:notes], incident_at: item[:incident_at],
                      confirmed_by: item[:confirmed_by], evidence_ref: item[:evidence_ref])
        { index: index, status: "recorded", id: report.id, phone_last4: report.phone_last4 }
      rescue Duplicate => e then failure(index, "duplicate", "duplicate_report", e.message)
      rescue PhoneNormalizer::Invalid => e then failure(index, "invalid", "invalid_phone", e.message)
      rescue InvalidIncidentDate => e then failure(index, "invalid", "invalid_incident_at", e.message)
      rescue ActiveRecord::RecordInvalid => e then failure(index, "invalid", "invalid_report", e.record.errors.full_messages.to_sentence.presence || "each report needs a phone and a reason_code")
      end
    end
  end

  def self.failure(index, status, code, message) = { index: index, status: status, error: { code: code, message: message } }
  private_class_method :failure

  def self.refile!(existing, p, reason_code, notes, incident, confirmed_by, evidence_ref)
    raise Duplicate, (existing.status == "removed" ? ALREADY_REMOVED : ALREADY_REPORTED) unless existing.status == "withdrawn"

    existing.update!(status: "active", reason_code: reason_code, notes: notes, incident_at: incident, confirmed_by: confirmed_by, evidence_ref: evidence_ref,
                     phone_ciphertext: p[:e164] || existing.phone_ciphertext, phone_last4: p[:last4] || existing.phone_last4)
    existing
  end
  private_class_method :refile!

  # Filing a report with a hash needs the last four digits (they are what merchants and admins see); withdrawing does not.
  def self.resolve(phone, phone_sha256, phone_last4, phone_length, last4_required: true)
    p = PhoneNormalizer.resolve(phone: phone, phone_sha256: phone_sha256, phone_last4: phone_last4, phone_length: phone_length)
    if last4_required && p[:e164].nil? && p[:last4].blank?
      raise PhoneNormalizer::Invalid, "phone_last4 (the last four digits) is required together with phone_sha256"
    end
    p
  end
  private_class_method :resolve

  # A date ("2026-08-14") or a full ISO 8601 time. Blank is fine; anything else that isn't a real, past date is refused.
  def self.parse_incident_at(value)
    return nil if value.blank?

    time = begin
      value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) ? Date.iso8601(value.to_s).in_time_zone : Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidIncidentDate, "incident_at must be an ISO 8601 date such as 2026-08-14"
    end
    raise InvalidIncidentDate, "incident_at can't be in the future" if time > Time.current
    time
  end
  private_class_method :parse_incident_at
end
