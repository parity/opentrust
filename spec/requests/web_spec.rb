require "rails_helper"

RSpec.describe "Web flow", type: :request do
  it "renders public pages" do
    %w[/ /faq /privacy /terms /docs /libraries /register /login /admin/login].each do |path|
      get path
      expect(response).to have_http_status(:ok), "#{path} returned #{response.status}"
      expect(response.body).to include("Built proudly in India, for India").and include('aria-label="Flag of India"')
    end
  end

  it "registers, waits for approval, gets free checks, creates a key and uses the API" do
    post "/register", params: { merchant: { business_name: "Acme", name: "Jo", contact_email: "jo@acme.test", phone: "98765 43210" }, password: "supersecret", accept_terms: "1" }
    expect(response).to redirect_to("/verify-email")
    get "/portal"
    expect(response).to redirect_to("/verify-email")

    code = ActionMailer::Base.deliveries.last.body.to_s[/\b\d{6}\b/]
    expect(code).to be_present
    post "/verify-email", params: { code: code }
    expect(response).to redirect_to("/portal")
    get "/portal"
    expect(response.body).to include("Waiting for approval")
    get "/portal/api_keys"
    expect(response.body).to include("Waiting for approval")

    merchant = Merchant.find_by!(contact_email: "jo@acme.test")
    expect(merchant.merchant_user.email_verified?).to be(true)
    expect(merchant.phone).to eq("+919876543210")
    expect(merchant.terms_accepted_at).to be_present
    expect(merchant.terms_version).to eq(OpenTrust::LEGAL_VERSION)
    admin = AdminUser.create!(email: "a@opentrust.test", password: "adminpass")
    MerchantApproval.approve!(merchant, admin)
    expect(merchant.reload.checks_remaining).to eq(OpenTrust::FREE_CHECKS)

    post "/portal/api_keys"
    token = response.body[/ot_live_\h+/]
    expect(token).to be_present
    post "/api/v1/lookups", params: { phone: "9000000009" }, headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:ok)
    expect(merchant.reload.checks_remaining).to eq(OpenTrust::FREE_CHECKS - 1)
  end

  it "admin can remove a report" do
    admin = AdminUser.create!(email: "a@opentrust.test", password: "adminpass")
    m = create(:merchant, checks_remaining: 0)
    report = ReportService.call(m, phone: "9876543210", reason_code: "other")
    post "/admin/login", params: { email: admin.email, password: "adminpass" }
    post "/admin/reports/#{report.id}/remove"
    expect(report.reload.status).to eq("removed")
    expect(FraudReport.active.where(id: report.id)).to be_empty
  end

  it "non-admins cannot reach admin" do
    get "/admin"
    expect(response).to redirect_to("/admin/login")
  end
end

RSpec.describe "Email verification", type: :request do
  def register!(email = "v@acme.test")
    post "/register", params: { merchant: { business_name: "Acme", name: "Jo", contact_email: email, phone: "9876543210" }, password: "supersecret", accept_terms: "1" }
    MerchantUser.find_by!(email: email)
  end

  it "rejects a wrong code, locks after too many attempts, and never stores the code in plaintext" do
    user = register!
    code = ActionMailer::Base.deliveries.last.body.to_s[/\b\d{6}\b/]
    expect(user.reload.otp_digest).not_to include(code)
    post "/verify-email", params: { code: "000000" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.email_verified?).to be(false)
    4.times { post "/verify-email", params: { code: "000000" } }
    post "/verify-email", params: { code: code }
    expect(user.reload.email_verified?).to be(false) # locked, even with the right code
  end

  it "rejects an expired code" do
    user = register!("e@acme.test")
    code = ActionMailer::Base.deliveries.last.body.to_s[/\b\d{6}\b/]
    user.update!(otp_expires_at: 1.minute.ago)
    post "/verify-email", params: { code: code }
    expect(user.reload.email_verified?).to be(false)
  end

  it "throttles resends and blocks approval of unverified merchants" do
    user = register!("r@acme.test")
    post "/verify-email/resend"
    expect(flash[:alert]).to include("wait")
    admin = AdminUser.create!(email: "a@opentrust.test", password: "adminpass")
    expect { MerchantApproval.approve!(user.merchant, admin) }.to raise_error(/not verified/)
  end
end

RSpec.describe "Registration without accepting terms", type: :request do
  it "is rejected" do
    post "/register", params: { merchant: { business_name: "Acme", name: "Jo", contact_email: "jo2@acme.test", phone: "9876543210" }, password: "supersecret" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Merchant.find_by(contact_email: "jo2@acme.test")).to be_nil
  end
end

RSpec.describe "Registration mobile number", type: :request do
  def attempt(phone, email)
    post "/register", params: { merchant: { business_name: "Acme", name: "Jo", contact_email: email, phone: phone }, password: "supersecret", accept_terms: "1" }
  end

  it "requires a valid 10-digit Indian mobile" do
    [["", "a@x.test"], ["12345", "b@x.test"], ["5876543210", "c@x.test"], ["98765432", "d@x.test"]].each do |phone, email|
      attempt(phone, email)
      expect(response).to have_http_status(:unprocessable_entity), "#{phone.inspect} should be rejected"
      expect(Merchant.find_by(contact_email: email)).to be_nil
    end
  end

  it "stores the number normalised as +91" do
    attempt("9876543210", "ok@x.test")
    expect(response).to redirect_to("/verify-email")
    expect(Merchant.find_by!(contact_email: "ok@x.test").phone).to eq("+919876543210")
  end
end

RSpec.describe "When the email provider fails", type: :request do
  it "still registers the merchant and shows a retry message instead of an error page" do
    allow(MerchantMailer).to receive(:verification_code).and_raise(StandardError, "provider down")
    post "/register", params: { merchant: { business_name: "Acme", name: "Jo", contact_email: "down@acme.test", phone: "9876543210" }, password: "supersecret", accept_terms: "1" }
    expect(response).to redirect_to("/verify-email")
    follow_redirect!
    expect(response.body).to include("couldn&#39;t send the email").or include("couldn't send the email")
  end
end

RSpec.describe "API docs libraries section", type: :request do
  it "says 'about to be published' until the SDKs are live, then shows SDK tabs" do
    get "/docs"
    expect(response.body).to include("id=\"libraries\"").and include("about to be published")
    expect(response.body).not_to include("Ruby gem</button>")

    stub_const("OpenTrust::SDKS_PUBLISHED", true)
    get "/docs"
    expect(response.body).not_to include("about to be published")
    expect(response.body).to include("Ruby gem</button>").and include("Node package</button>")
  end
end

RSpec.describe RetentionPurge do
  def report(merchant, created:, status: "active", hold: false, phone: SecureRandom.hex(4))
    p = PhoneNormalizer.call("98#{rand(10**8).to_s.rjust(8, '0')}")
    FraudReport.create!(merchant: merchant, phone_hash: p[:hash] + phone, phone_ciphertext: p[:e164], phone_last4: p[:last4],
                        reason_code: "other", status: status, legal_hold: hold, created_at: created, updated_at: created)
  end

  it "deletes expired and long-removed reports, keeps recent ones and anything on legal hold" do
    m = create(:merchant)
    old      = report(m, created: 61.months.ago)
    held     = report(m, created: 80.months.ago, hold: true)
    recent   = report(m, created: 4.years.ago)
    gone     = report(m, created: 4.months.ago, status: "removed")
    just_now = report(m, created: 10.days.ago, status: "removed")
    AuditLog.create!(action: "x", created_at: 4.years.ago)
    fresh_log = AuditLog.create!(action: "y", created_at: 1.month.ago)

    counts = RetentionPurge.call
    expect(counts).to eq(expired_reports: 1, removed_reports: 1, audit_logs: 1)
    expect(FraudReport.where(id: [old.id, gone.id])).to be_empty
    expect(FraudReport.where(id: [held.id, recent.id, just_now.id]).count).to eq(3)
    expect(AuditLog.where(id: fresh_log.id)).to exist
  end
end

RSpec.describe "OpenTrust.secret_ok?" do
  it "accepts real secrets and rejects placeholders and short values" do
    expect(OpenTrust.secret_ok?(SecureRandom.hex(32))).to be(true)
    expect(OpenTrust.secret_ok?("Qm9o3Zq2Ld8VnR5tYw7XaP1cKe6HsGuJ")).to be(true)
    ["REPLACE_IN_CONSOLE", "change-me-now-please", "your-example-secret-value", "short", "", nil].each { |v| expect(OpenTrust.secret_ok?(v)).to be(false), v.inspect }
  end
end
