require "rails_helper"

RSpec.describe "API v1", type: :request do
  let(:reporter) { create(:merchant, business_name: "Zingoy", checks_remaining: 0) }
  let(:checker) { create(:merchant, checks_remaining: 10) }
  let!(:reporter_token) { ApiKey.issue!(reporter).last }
  let!(:checker_token) { ApiKey.issue!(checker).last }
  def auth(t) = { "Authorization" => "Bearer #{t}" }

  it "requires a valid key" do
    post "/api/v1/lookups", params: { phone: "9876543210" }
    expect(response).to have_http_status(401)
  end

  it "reporting records the report but earns nothing, and a duplicate gets 409" do
    post "/api/v1/reports", params: { phone: "9876543210", reason_code: "cod_refusal", notes: "refused 3 COD orders" }, headers: auth(reporter_token)
    expect(response).to have_http_status(201)
    expect(JSON.parse(response.body)).to include("status" => "recorded")
    expect(reporter.reload.checks_remaining).to eq(0)
    expect(reporter.check_ledger_entries.count).to eq(0)
    post "/api/v1/reports", params: { phone: "+91 98765 43210", reason_code: "cod_refusal" }, headers: auth(reporter_token)
    expect(response).to have_http_status(409)
  end

  it "rejects notes containing contact details" do
    post "/api/v1/reports", params: { phone: "9876543210", reason_code: "other", notes: "call 9123456789" }, headers: auth(reporter_token)
    expect(response).to have_http_status(422)
  end

  it "lookup returns anonymous report details, charges 1 credit, and never leaks the full number" do
    post "/api/v1/reports", params: { phone: "9876543210", reason_code: "chargeback", notes: "fraud" }, headers: auth(reporter_token)
    post "/api/v1/lookups", params: { phone: "09876543210" }, headers: auth(checker_token)
    body = JSON.parse(response.body)
    expect(body["report_count"]).to eq(1)
    expect(body["reports"].first).to include("reason_code" => "chargeback", "reason" => "Disputed a payment (chargeback)", "notes" => "fraud", "reporter_verified" => true)
    expect(body["reports"].first).not_to have_key("merchant")
    expect(response.body).not_to include("Zingoy")
    expect(body["checks_remaining"]).to eq(9)
    expect(body["notice"]).to include("unverified")
    expect(response.body).not_to include("9876543210")
  end

  it "returns an empty array for unknown numbers and 402 when out of checks" do
    post "/api/v1/lookups", params: { phone: "9000000001" }, headers: auth(checker_token)
    expect(JSON.parse(response.body)).to include("reported" => false, "report_count" => 0, "reports" => [])
    checker.update!(checks_remaining: 0)
    post "/api/v1/lookups", params: { phone: "9000000001" }, headers: auth(checker_token)
    expect(response).to have_http_status(402)
  end

  it "batch is all-or-nothing on balance" do
    checker.update!(checks_remaining: 1)
    post "/api/v1/lookups/batch", params: { phones: %w[9000000001 9000000002] }, as: :json, headers: auth(checker_token)
    expect(response).to have_http_status(402)
    expect(checker.reload.checks_remaining).to eq(1)
  end

  it "blocks unapproved merchants" do
    checker.update!(status: "suspended")
    post "/api/v1/lookups", params: { phone: "9000000001" }, headers: auth(checker_token)
    expect(response).to have_http_status(403)
  end
end

RSpec.describe Checks::Ledger do
  self.use_transactional_tests = false
  after { CheckLedgerEntry.delete_all; Merchant.delete_all }

  it "cannot be overdrawn by concurrent lookups" do
    m = create(:merchant, checks_remaining: 5)
    threads = 10.times.map { Thread.new { ActiveRecord::Base.connection_pool.with_connection { Checks::Ledger.apply!(Merchant.find(m.id), -1, reason: "lookup") rescue Checks::Ledger::Insufficient } } }
    threads.each(&:join)
    expect(m.reload.checks_remaining).to eq(0)
    expect(m.check_ledger_entries.count).to eq(5)
  end
end

RSpec.describe "Impersonation reasons", type: :request do
  it "accepts impersonation fraud reason codes" do
    m = create(:merchant, checks_remaining: 0)
    token = ApiKey.issue!(m).last
    post "/api/v1/reports", params: { phone: "9812345678", reason_code: "otp_fraud", notes: "Posed as bank rep asking for OTP" }, headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(201)
    post "/api/v1/reports", params: { phone: "9812345679", reason_code: "not_a_code" }, headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(422)
  end
end
