class Merchant < ApplicationRecord
  STATUSES = %w[pending approved rejected suspended].freeze

  has_one :merchant_user, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :fraud_reports, dependent: :restrict_with_error
  has_many :check_ledger_entries, dependent: :restrict_with_error

  validates :name, :business_name, :contact_email, presence: true
  validates :contact_email, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }

  # Contact mobile is collected at registration (Indian mobile, stored as +91XXXXXXXXXX).
  before_validation :normalize_phone, on: :create
  validates :phone, presence: { message: "is required" }, on: :create
  validate :phone_is_indian_mobile, on: :create, if: -> { phone.present? }

  STATUSES.each { |s| define_method("#{s}?") { status == s } }

  private

  def normalize_phone
    self.phone = PhoneNormalizer.e164(phone) if phone.present?
  rescue PhoneNormalizer::Invalid
    nil # left as typed so the validation below can reject it
  end

  def phone_is_indian_mobile
    errors.add(:phone, "must be a 10-digit Indian mobile number") unless phone.to_s.match?(/\A\+91[6-9]\d{9}\z/)
  end
end
