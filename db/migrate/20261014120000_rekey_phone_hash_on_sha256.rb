# The stored key used to be HMAC(secret, number). It is now HMAC(secret, sha256(number)), so that a client can send the SHA-256
# of a number and we match it without ever seeing the number. Every existing row is re-keyed from its stored (encrypted) number.
# A report that arrives as a hash alone has no number, so phone_ciphertext may now be empty.
class RekeyPhoneHashOnSha256 < ActiveRecord::Migration[7.1]
  class Report < ApplicationRecord
    self.table_name = "fraud_reports"
    encrypts :phone_ciphertext
  end

  def up
    change_column_null :fraud_reports, :phone_ciphertext, true
    Report.reset_column_information
    Report.find_each do |r|
      next if r.phone_ciphertext.blank?

      r.update_columns(phone_hash: PhoneNormalizer.hash(PhoneNormalizer.sha256(r.phone_ciphertext)))
    end
  end

  def down
    Report.reset_column_information
    raise ActiveRecord::IrreversibleMigration, "reports filed as a hash alone have no number to re-key" if Report.where(phone_ciphertext: nil).exists?

    Report.find_each { |r| r.update_columns(phone_hash: OpenSSL::HMAC.hexdigest("SHA256", OpenTrust.phone_pepper, r.phone_ciphertext)) }
    change_column_null :fraud_reports, :phone_ciphertext, false
  end
end
