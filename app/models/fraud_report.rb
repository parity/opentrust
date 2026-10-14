class FraudReport < ApplicationRecord
  # The codes, labels and descriptions live in ReasonCatalog. These stay so views and specs keep working.
  REASON_GROUPS = ReasonCatalog.groups.freeze
  REASON_CODES = ReasonCatalog.codes.freeze
  CONFIRMED_BY = %w[bank payment_gateway law_enforcement].freeze # self-declared by the reporter; OpenTrust does not verify it
  STATUSES = %w[active removed withdrawn].freeze # removed = by an admin; withdrawn = by the merchant who filed it

  def self.label_for(code) = ReasonCatalog.label(code)

  belongs_to :merchant
  encrypts :phone_ciphertext
  encrypts :evidence_ref # a private reference (a complaint or ticket number); only admins ever see it, never in lookups

  scope :active, -> { where(status: "active") }

  # phone_ciphertext is empty when the merchant sent only the SHA-256 of the number; we then know the last four digits only because they told us.
  validates :phone_hash, :phone_last4, presence: true
  validates :phone_last4, format: { with: /\A\d{4}\z/, message: "must be four digits" }, allow_blank: true
  validates :reason_code, inclusion: { in: REASON_CODES }
  validates :status, inclusion: { in: STATUSES }
  validates :notes, length: { maximum: 500 }
  validate :notes_contain_no_contact_details
  validate :other_needs_a_note
  validates :confirmed_by, inclusion: { in: CONFIRMED_BY, message: "must be one of #{CONFIRMED_BY.join(', ')}" }, allow_nil: true
  validate :evidence_needs_confirmation

  PII_PATTERN = /(\S+@\S+\.\S+)|(https?:\/\/|www\.)|(\+?\d[\d\s\-]{8,}\d)/i

  private

  def evidence_needs_confirmation
    return if evidence_ref.blank?

    errors.add(:evidence_ref, "can only be sent together with confirmed_by") if confirmed_by.blank?
    errors.add(:evidence_ref, "is too long (100 characters at most)") if evidence_ref.to_s.length > 100
  end

  def other_needs_a_note
    errors.add(:notes, "are required (at least 10 characters) when the reason is 'other'") if reason_code == "other" && notes.to_s.strip.length < 10
  end

  def notes_contain_no_contact_details
    errors.add(:notes, "must not contain emails, links or phone numbers") if notes.present? && notes.match?(PII_PATTERN)
  end
end
