class LookupService
  MAX_BATCH = 100

  # Uses 1 check per number, all-or-nothing, then returns one result per number.
  #
  # `reports` and `report_count` only ever hold OTHER merchants' reports: a merchant's own report is not a signal from anyone
  # else. `own_report` says whether the asking merchant has filed one itself.
  def self.call(merchant, raw_phones)
    phones = Array(raw_phones).map { |p| PhoneNormalizer.call(p) }
    Checks::Ledger.apply!(merchant, -phones.size, reason: "lookup", memo: "#{phones.size} check(s)")
    matching = FraudReport.active.where(phone_hash: phones.map { |p| p[:hash] })
    others = matching.where.not(merchant_id: merchant.id).group_by(&:phone_hash)
    own = matching.where(merchant_id: merchant.id).pluck(:phone_hash).to_set
    phones.map do |p|
      list = others.fetch(p[:hash], [])
      # Reporter identity is deliberately never returned; admins can see it for moderation.
      { phone_last4: p[:last4], reported: list.any?, report_count: list.size, own_report: own.include?(p[:hash]),
        reports: list.sort_by(&:created_at).reverse.map { |r| present(r) } }
    end
  end

  def self.present(r)
    { reason_code: r.reason_code, reason: FraudReport.label_for(r.reason_code), notes: r.notes,
      incident_at: r.incident_at&.to_date&.iso8601, confirmed_by: r.confirmed_by, reported_at: r.created_at.to_date.iso8601, reporter_verified: true }
  end
  private_class_method :present
end
