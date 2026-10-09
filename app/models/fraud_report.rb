class FraudReport < ApplicationRecord
  # Grouped for display. The flat codes are the API contract.
  REASON_GROUPS = {
    "Orders and payments" => %w[cod_refusal fake_order return_abuse chargeback fake_payment_proof],
    "Impersonation and phone calls" => %w[otp_fraud bank_impersonation merchant_impersonation phishing_link kyc_scam refund_scam],
    "Other" => %w[identity_fraud other]
  }.freeze
  REASON_CODES = REASON_GROUPS.values.flatten.freeze

  # Labels describe what the merchant observed, not a conclusion about the person.
  REASON_LABELS = {
    "cod_refusal" => "Refused a cash-on-delivery order",
    "fake_order" => "Placed an order that appeared fake",
    "return_abuse" => "Repeated return or refund abuse",
    "chargeback" => "Disputed a payment (chargeback)",
    "fake_payment_proof" => "Shared payment proof that didn't check out",
    "otp_fraud" => "Asked someone for an OTP",
    "bank_impersonation" => "Posed as a bank or financial institution",
    "merchant_impersonation" => "Posed as our business or support",
    "phishing_link" => "Sent a suspicious payment or login link",
    "kyc_scam" => "Posed as a KYC or verification agent",
    "refund_scam" => "Made a suspicious refund request",
    "identity_fraud" => "Used someone else's identity details",
    "other" => "Other"
  }.freeze

  def self.label_for(code) = REASON_LABELS.fetch(code, code.to_s.humanize)

  belongs_to :merchant
  encrypts :phone_ciphertext

  scope :active, -> { where(status: "active") }

  validates :phone_hash, :phone_ciphertext, :phone_last4, presence: true
  validates :reason_code, inclusion: { in: REASON_CODES }
  validates :status, inclusion: { in: %w[active removed] }
  validates :notes, length: { maximum: 500 }
  validate :notes_contain_no_contact_details

  PII_PATTERN = /(\S+@\S+\.\S+)|(https?:\/\/|www\.)|(\+?\d[\d\s\-]{8,}\d)/i

  private

  def notes_contain_no_contact_details
    errors.add(:notes, "must not contain emails, links or phone numbers") if notes.present? && notes.match?(PII_PATTERN)
  end
end
