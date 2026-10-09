module Checks
  # The only code path that mutates merchants.checks_remaining.
  class Ledger
    class Insufficient < StandardError; end

    def self.apply!(merchant, delta, reason:, memo: nil)
      merchant.with_lock do
        new_balance = merchant.checks_remaining + delta
        raise Insufficient, "no checks remaining" if new_balance.negative?
        merchant.update_columns(checks_remaining: new_balance, updated_at: Time.current)
        CheckLedgerEntry.create!(merchant: merchant, delta: delta, balance_after: new_balance, reason: reason, memo: memo)
      end
    end
  end
end
