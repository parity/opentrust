class CheckLedgerEntry < ApplicationRecord
  REASONS = %w[signup_grant lookup admin_adjust].freeze
  belongs_to :merchant
  validates :reason, inclusion: { in: REASONS }
  before_update { raise ActiveRecord::ReadOnlyRecord, "ledger is append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "ledger is append-only" }
end
