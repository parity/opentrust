module Portal
  class LedgerController < BaseController
    def index = (@entries = current_merchant.check_ledger_entries.order(id: :desc).limit(200))
  end
end
