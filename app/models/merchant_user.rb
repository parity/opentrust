class MerchantUser < ApplicationRecord
  has_secure_password
  belongs_to :merchant
  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  def email_verified? = email_verified_at.present?
end
