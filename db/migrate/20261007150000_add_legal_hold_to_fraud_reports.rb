class AddLegalHoldToFraudReports < ActiveRecord::Migration[7.1]
  def change
    # Lets us keep a report past its retention period while a complaint or legal claim is open.
    add_column :fraud_reports, :legal_hold, :boolean, null: false, default: false
  end
end
