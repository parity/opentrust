class ApiKey < ApplicationRecord
  belongs_to :merchant
  scope :active, -> { where(revoked_at: nil) }

  def self.digest(token) = Digest::SHA256.hexdigest(token)

  # Returns [record, plaintext]; plaintext is shown to the merchant exactly once.
  def self.issue!(merchant, label: nil)
    token = "ot_live_#{SecureRandom.hex(24)}"
    [create!(merchant: merchant, key_digest: digest(token), prefix: token[0, 12], label: label), token]
  end

  def self.authenticate(token)
    return nil if token.blank?
    active.includes(:merchant).find_by(key_digest: digest(token))
  end

  def revoke! = update!(revoked_at: Time.current)
end
