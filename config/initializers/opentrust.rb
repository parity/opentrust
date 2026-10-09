module OpenTrust
  FREE_CHECKS = 100_000 # granted to every approved merchant; more on request
  FEEDBACK_EMAIL = ENV.fetch("FEEDBACK_EMAIL", "feedback@opentrust.in") # set to a live inbox until opentrust.in mail exists
  GRIEVANCE_EMAIL = ENV.fetch("GRIEVANCE_EMAIL", "grievance@opentrust.in") # placeholder until confirmed
  LEGAL_VERSION = "2026-10-07" # bump (and update LEGAL_EFFECTIVE) whenever the Terms or Privacy Policy change materially
  LEGAL_EFFECTIVE = "7 October 2026"
  # The legal entity that operates OpenTrust, shown in the Terms and Privacy Policy.
  OPERATOR = {
    name: ENV.fetch("OPERATOR_NAME", "Parity Cube Pvt Ltd"),
    address: ENV.fetch("OPERATOR_ADDRESS", "D/6 Goragandhi, Opp Railway Station, Chandavarkar Road, Borivali West, Mumbai 400091")
  }.freeze
  # Grievance Officer shown in the Terms and Privacy Policy (IT Rules, 2021 require a named officer).
  GRIEVANCE_OFFICER = {
    name: ENV.fetch("GRIEVANCE_OFFICER_NAME", "Jimish Jobanputra"),
    designation: ENV.fetch("GRIEVANCE_OFFICER_DESIGNATION", "Co-Founder"),
    address: ENV.fetch("GRIEVANCE_OFFICER_ADDRESS", "Borivali West, Mumbai")
  }.freeze
  COFFEE_URL = ENV["COFFEE_URL"].presence # optional "buy us a coffee" link, shown only when set
  # Flip SDKS_PUBLISHED=true once the gem and npm package are live; until then the docs say "coming soon".
  SDKS_PUBLISHED = ENV["SDKS_PUBLISHED"] == "true"
  REPO_URL = ENV["REPO_URL"].presence # public source repo, linked from the docs when set
  LOOKUP_NOTICE = "Reports are unverified observations shared by individual merchants. They are not a finding that anyone committed fraud. Use them as one input among others, not as the sole reason to refuse a customer.".freeze

  # Merchants who agreed to be shown publicly on the landing page. Report authorship stays anonymous.
  PARTICIPANTS = [
    { name: "Zingoy", logo: "merchants/zingoy.png", url: "https://zingoy.com" }
  ].freeze

  # A real secret: long enough, and not a placeholder someone forgot to replace (deployment specs in git carry
  # placeholders, and data encrypted under a known placeholder would be effectively unencrypted).
  def self.secret_ok?(value)
    v = value.to_s
    v.length >= 16 && v !~ /replace|change[_ -]?me|placeholder|example/i
  end

  def self.phone_pepper
    ENV.fetch("PHONE_HASH_PEPPER") do
      raise "PHONE_HASH_PEPPER must be set" if Rails.env.production?
      "dev-only-pepper"
    end.tap do |v|
      raise "PHONE_HASH_PEPPER looks like a placeholder or is too short (use `openssl rand -hex 32`)" if Rails.env.production? && !secret_ok?(v)
    end
  end
end

# Active Record encryption keys (used for fraud_reports.phone_ciphertext).
# SECRET_KEY_BASE_DUMMY is set only while building the Docker image (assets:precompile), never at runtime,
# so a real deployment still refuses to boot without the real keys.
building_image = ENV["SECRET_KEY_BASE_DUMMY"].present?
enc = lambda do |name, dev|
  ENV.fetch(name) { Rails.env.production? && !building_image ? raise("#{name} must be set") : dev }.tap do |v|
    raise "#{name} looks like a placeholder or is too short (use `bin/rails db:encryption:init`)" if Rails.env.production? && !building_image && !OpenTrust.secret_ok?(v)
  end
end
Rails.application.config.active_record.encryption.primary_key = enc.("AR_ENC_PRIMARY_KEY", "dev-primary-key-0123456789abcdef")
Rails.application.config.active_record.encryption.deterministic_key = enc.("AR_ENC_DETERMINISTIC_KEY", "dev-determ-key-0123456789abcdef")
Rails.application.config.active_record.encryption.key_derivation_salt = enc.("AR_ENC_SALT", "dev-salt-0123456789abcdef")
