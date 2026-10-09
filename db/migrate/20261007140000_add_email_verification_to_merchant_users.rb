class AddEmailVerificationToMerchantUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :merchant_users, :email_verified_at, :datetime
    add_column :merchant_users, :otp_digest, :string
    add_column :merchant_users, :otp_expires_at, :datetime
    add_column :merchant_users, :otp_attempts, :integer, null: false, default: 0
    add_column :merchant_users, :otp_last_sent_at, :datetime
    add_column :merchant_users, :otp_sends_in_window, :integer, null: false, default: 0
    add_column :merchant_users, :otp_window_started_at, :datetime
    # Accounts that existed before verification was introduced stay usable.
    execute "UPDATE merchant_users SET email_verified_at = NOW() WHERE email_verified_at IS NULL"
  end

  def down
    %i[email_verified_at otp_digest otp_expires_at otp_attempts otp_last_sent_at otp_sends_in_window otp_window_started_at].each { |c| remove_column :merchant_users, c }
  end
end
