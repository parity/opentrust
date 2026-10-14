class AdminUser < ApplicationRecord
  has_secure_password
  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :email, presence: true, uniqueness: true
  # Admins can read decrypted numbers, so their passwords are held to a higher bar than merchants'. allow_nil: an existing admin
  # who is not changing the password is not asked to.
  validates :password, length: { minimum: 12 }, allow_nil: true
end
