class LookupService
  MAX_BATCH = 100

  # Uses 1 check per number, all-or-nothing, then returns one result per number.
  def self.call(merchant, raw_phones)
    phones = Array(raw_phones).map { |p| PhoneNormalizer.call(p) }
    Checks::Ledger.apply!(merchant, -phones.size, reason: "lookup", memo: "#{phones.size} check(s)")
    reports = FraudReport.active.where(phone_hash: phones.map { |p| p[:hash] }).group_by(&:phone_hash)
    phones.map do |p|
      list = reports.fetch(p[:hash], [])
      # Reporter identity is deliberately never returned; admins can see it for moderation.
      { phone_last4: p[:last4], reported: list.any?, report_count: list.size,
        reports: list.sort_by(&:created_at).reverse.map { |r| { reason_code: r.reason_code, reason: FraudReport.label_for(r.reason_code), notes: r.notes, reported_at: r.created_at.to_date.iso8601, reporter_verified: true } } }
    end
  end
end
