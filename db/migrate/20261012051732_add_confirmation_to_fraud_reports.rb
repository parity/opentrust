class AddConfirmationToFraudReports < ActiveRecord::Migration[7.1]
  def change
    add_column :fraud_reports, :confirmed_by, :string
    add_column :fraud_reports, :evidence_ref, :text
  end
end
