require "rails_helper"

RSpec.describe "API v1 additions", type: :request do
  let(:reporter) { create(:merchant) }
  let(:checker) { create(:merchant, checks_remaining: 20) }
  let!(:reporter_token) { ApiKey.issue!(reporter).last }
  let!(:checker_token) { ApiKey.issue!(checker).last }
  def auth(t) = { "Authorization" => "Bearer #{t}" }
  def json = JSON.parse(response.body)
  def post_json(path, body, token) = post(path, params: body, as: :json, headers: auth(token))

  describe "POST /reports/batch" do
    it "files good rows and reports each bad row on its own, in order" do
      post_json "/api/v1/reports/batch", { reports: [
        { phone: "9876543210", reason_code: "chargeback", notes: "Card payment disputed", incident_at: "2026-08-14" },
        { phone: "98765 43210", reason_code: "chargeback" },
        { phone: "12345", reason_code: "chargeback" },
        { phone: "9812345678", reason_code: "not_a_code" },
        { phone: "9812345679", reason_code: "other" },
        { phone: "9812345670", reason_code: "chargeback", incident_at: "yesterday" },
        { phone: "9812345671", reason_code: "chargeback", incident_at: 1.week.from_now.to_date.iso8601 },
        { phone: "9812345672", reason_code: "fake_order" }
      ] }, reporter_token
      expect(response).to have_http_status(200)
      expect(json["results"].map { |r| r["status"] }).to eq(%w[recorded duplicate invalid invalid invalid invalid invalid recorded])
      expect(json["results"].map { |r| r["index"] }).to eq((0..7).to_a)
      expect(json["results"][0]).to include("phone_last4" => "3210").and have_key("id")
      expect(json["results"][1]["error"]["code"]).to eq("duplicate_report")
      expect(json["results"][2]["error"]["code"]).to eq("invalid_phone")
      expect(json["results"][3]["error"]["code"]).to eq("invalid_report")
      expect(json["results"][4]["error"]["message"]).to include("other")
      expect(json["results"][5]["error"]["code"]).to eq("invalid_incident_at")
      expect(json["results"][6]["error"]["message"]).to include("future")
      expect(json["summary"]).to eq("recorded" => 2, "duplicate" => 1, "invalid" => 5)
      expect(reporter.fraud_reports.count).to eq(2)
      expect(response.body).not_to include("9876543210")
    end

    it "costs nothing and refuses an empty, oversized or malformed list" do
      post_json "/api/v1/reports/batch", { reports: [] }, reporter_token
      expect(response).to have_http_status(422)
      post_json "/api/v1/reports/batch", { reports: Array.new(101) { { phone: "9876543210", reason_code: "chargeback" } } }, reporter_token
      expect(response).to have_http_status(422)
      expect(json["error"]["code"]).to eq("invalid_reports")
      post_json "/api/v1/reports/batch", { reports: "nope" }, reporter_token
      expect(response).to have_http_status(422)
      post_json "/api/v1/reports/batch", { reports: ["9876543210", 5] }, reporter_token
      expect(json["summary"]).to eq("recorded" => 0, "duplicate" => 0, "invalid" => 2)
    end

    it "needs a key" do
      post "/api/v1/reports/batch", params: { reports: [] }, as: :json
      expect(response).to have_http_status(401)
    end
  end

  describe "incident_at and own_report in lookups" do
    it "returns the incident date, and never counts the asking merchant's own report as a signal from others" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback", notes: "Disputed", incident_at: "2026-08-14" }, reporter_token
      expect(response).to have_http_status(201)

      post_json "/api/v1/lookups", { phone: "9876543210" }, checker_token
      expect(json).to include("reported" => true, "report_count" => 1, "own_report" => false)
      expect(json["reports"].first).to include("incident_at" => "2026-08-14", "reported_at" => Date.current.iso8601)

      post_json "/api/v1/lookups", { phone: "9876543210" }, reporter_token
      expect(json).to include("reported" => false, "report_count" => 0, "own_report" => true, "reports" => [])
    end

    it "gives a null incident date when none was sent, and works in batch lookups" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "fake_order" }, reporter_token
      post_json "/api/v1/lookups/batch", { phones: %w[9876543210 9000000001] }, checker_token
      expect(json["results"][0]["reports"].first["incident_at"]).to be_nil
      expect(json["results"].map { |r| r["own_report"] }).to eq([false, false])
    end
  end

  describe "DELETE /reports" do
    it "withdraws your own report: it leaves lookups at once, and you can file it again" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback", notes: "First" }, reporter_token
      delete "/api/v1/reports", params: { phone: "+91 98765 43210" }, as: :json, headers: auth(reporter_token)
      expect(response).to have_http_status(200)
      expect(json).to eq("phone_last4" => "3210", "status" => "withdrawn")

      post_json "/api/v1/lookups", { phone: "9876543210" }, checker_token
      expect(json).to include("reported" => false, "report_count" => 0)
      post_json "/api/v1/lookups", { phone: "9876543210" }, reporter_token
      expect(json["own_report"]).to be(false)

      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "fake_order", notes: "Second time" }, reporter_token
      expect(response).to have_http_status(201)
      expect(reporter.fraud_reports.count).to eq(1)
      post_json "/api/v1/lookups", { phone: "9876543210" }, checker_token
      expect(json["reports"].first).to include("reason_code" => "fake_order", "notes" => "Second time")
    end

    it "accepts the number in the query string, and answers 404 when there is nothing to withdraw" do
      delete "/api/v1/reports", params: { phone: "9876543210" }, headers: auth(reporter_token)
      expect(response).to have_http_status(404)
      expect(json["error"]["code"]).to eq("report_not_found")
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, reporter_token
      delete "/api/v1/reports?phone=9876543210", headers: auth(reporter_token)
      expect(response).to have_http_status(200)
      delete "/api/v1/reports?phone=9876543210", headers: auth(reporter_token)
      expect(response).to have_http_status(404)
    end

    it "only ever touches your own report" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, reporter_token
      delete "/api/v1/reports", params: { phone: "9876543210" }, as: :json, headers: auth(checker_token)
      expect(response).to have_http_status(404)
      expect(reporter.fraud_reports.active.count).to eq(1)
    end

    it "does not let a merchant file again after an admin removed the report" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, reporter_token
      reporter.fraud_reports.first.update!(status: "removed")
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, reporter_token
      expect(response).to have_http_status(409)
      expect(json["error"]["message"]).to include("removed")
      delete "/api/v1/reports", params: { phone: "9876543210" }, as: :json, headers: auth(reporter_token)
      expect(response).to have_http_status(404)
    end
  end

  describe "incident_at on a single report" do
    it "rejects a future date or nonsense with 422 and a clear code" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback", incident_at: 2.days.from_now.to_date.iso8601 }, reporter_token
      expect(response).to have_http_status(422)
      expect(json["error"]["code"]).to eq("invalid_incident_at")
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback", incident_at: "14/08/2026" }, reporter_token
      expect(response).to have_http_status(422)
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback", incident_at: "2026-08-14T10:30:00+05:30" }, reporter_token
      expect(response).to have_http_status(201)
    end
  end

  describe "confirmed_by and evidence_ref" do
    it "shows who confirmed a report in lookups, and never shows the private reference" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback", confirmed_by: "payment_gateway", evidence_ref: "GW-CASE-48213" }, reporter_token
      expect(response).to have_http_status(201)
      report = reporter.fraud_reports.first
      expect(report.confirmed_by).to eq("payment_gateway")
      expect(report.evidence_ref).to eq("GW-CASE-48213")
      expect(FraudReport.connection.select_value("select evidence_ref from fraud_reports where id = #{report.id}")).not_to include("GW-CASE-48213")

      post_json "/api/v1/lookups", { phone: "9876543210" }, checker_token
      expect(json["reports"].first).to include("confirmed_by" => "payment_gateway")
      expect(response.body).not_to include("GW-CASE-48213")
    end

    it "is null when nobody confirmed, and rejects unknown values and a reference without a confirmation" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "fake_order" }, reporter_token
      post_json "/api/v1/lookups", { phone: "9876543210" }, checker_token
      expect(json["reports"].first["confirmed_by"]).to be_nil

      post_json "/api/v1/reports", { phone: "9812345678", reason_code: "fake_order", confirmed_by: "my cousin" }, reporter_token
      expect(response).to have_http_status(422)
      post_json "/api/v1/reports", { phone: "9812345678", reason_code: "fake_order", evidence_ref: "X-1" }, reporter_token
      expect(response).to have_http_status(422)
      post_json "/api/v1/reports", { phone: "9812345678", reason_code: "fake_order", confirmed_by: "bank", evidence_ref: "x" * 101 }, reporter_token
      expect(response).to have_http_status(422)
    end

    it "works in a batch and when filing again after a withdrawal" do
      post_json "/api/v1/reports/batch", { reports: [{ phone: "9876543210", reason_code: "chargeback", confirmed_by: "bank", evidence_ref: "R1" }, { phone: "9812345678", reason_code: "chargeback", confirmed_by: "nobody" }] }, reporter_token
      expect(json["results"].map { |r| r["status"] }).to eq(%w[recorded invalid])
      delete "/api/v1/reports", params: { phone: "9876543210" }, as: :json, headers: auth(reporter_token)
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, reporter_token
      expect(reporter.fraud_reports.first.confirmed_by).to be_nil
    end
  end

  describe "GET /reason_codes and the catalog" do
    it "lists every offered code with a group, label and description" do
      get "/api/v1/reason_codes", headers: auth(checker_token)
      expect(response).to have_http_status(200)
      codes = json["reason_codes"]
      expect(codes.map { |c| c["code"] }).to eq(ReasonCatalog.codes)
      expect(codes).to all(include("code", "group", "label", "description", "use_when", "not_when"))
      expect(checker.reload.checks_remaining).to eq(20)
    end

    it "keeps every code, label and description non-empty and phrased as an observation" do
      ReasonCatalog::ENTRIES.each do |e|
        expect(e.label).to be_present
        expect(e.description).to end_with(".")
        expect(e.use_when).to be_present
        expect(e.not_when).to be_present
        expect(e.code).to match(/\A[a-z]+(_[a-z]+)*\z/)
      end
      expect(ReasonCatalog.codes.uniq.size).to eq(ReasonCatalog.codes.size)
      expect(FraudReport::REASON_CODES).to eq(ReasonCatalog.codes)
    end

    it "keeps the OpenAPI file and the docs page in step with the catalog" do
      spec = YAML.load_file(Rails.root.join("public/openapi.yml"))
      expect(spec.dig("components", "schemas", "ReportInput", "properties", "reason_code", "enum")).to eq(ReasonCatalog.codes)
      get "/docs"
      ReasonCatalog.offered.each { |e| expect(response.body).to include(e.code, ERB::Util.html_escape(e.description)) }
      %w[/reports/batch /reason_codes].each { |path| expect(spec["paths"]).to have_key(path) }
      expect(spec["paths"]["/reports"]).to have_key("delete")
    end

    it "accepts every code in the catalog, and the groups read as display names only" do
      ReasonCatalog.codes.reject { |c| c == "other" }.each_with_index do |code, i|
        post_json "/api/v1/reports", { phone: "98123456#{format('%02d', i)}", reason_code: code }, reporter_token
        expect(response).to have_http_status(201), "#{code} was refused: #{response.body}"
      end
      expect(ReasonCatalog.codes).to include("promo_abuse", "document_mismatch", "third_party_payment_fraud")
      expect(ReasonCatalog.codes).not_to include("account_takeover")
    end

    it "requires a note for 'other' on a single report too" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "other" }, reporter_token
      expect(response).to have_http_status(422)
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "other", notes: "Asked for a gift card code" }, reporter_token
      expect(response).to have_http_status(201)
    end
  end
end
