class RenameKarmaToChecks < ActiveRecord::Migration[7.1]
  def change
    rename_table :karma_ledger_entries, :check_ledger_entries
    rename_column :check_ledger_entries, :delta_credits, :delta
    rename_column :merchants, :lookup_credits, :checks_remaining
  end
end
