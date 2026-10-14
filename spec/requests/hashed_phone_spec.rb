require "rails_helper"

# A merchant may send the SHA-256 of a number instead of the number. Both must end up on the same key.
RSpec.describe "Hashed phone numbers", type: :request do
  VECTORS = JSON.parse(File.read(Rails.root.join("sdks/phone-hash-vectors.json"))).freeze
  let(:reporter) { create(:merchant) }
  let(:checker) { create(:merchant, checks_remaining: 20) }
  let(:rtoken) { ApiKey.issue!(reporter).last }
  let(:ctoken) { ApiKey.issue!(checker).last }
  let(:number) { "+919876543210" }
  let(:sha) { Digest::SHA256.hexdigest(number) }
  def auth(t) = { "Authorization" => "Bearer #{t}" }
  def json = JSON.parse(response.body)
  def post_json(path, body, token) = post(path, params: body, as: :json, headers: auth(token))

  describe "the shared test vectors (the same file the SDKs are tested against)" do
    it "normalises every accepted spelling to the same number and SHA-256" do
      VECTORS["valid"].each do |v|
        r = PhoneNormalizer.call(v["input"])
        expect([r[:e164], r[:sha256]]).to eq([v["e164"], v["sha256"]]), "failed for #{v['input'].inspect}"
      end
    end

    it "rejects everything that is not an Indian mobile number" do
      VECTORS["invalid"].each { |i| expect { PhoneNormalizer.call(i) }.to raise_error(PhoneNormalizer::Invalid), "accepted #{i.inspect}" }
    end
  end

  it "stores the same key whether a number or its SHA-256 arrives" do
    expect(PhoneNormalizer.call("98765 43210")[:hash]).to eq(PhoneNormalizer.from_sha256(sha, length: 13)[:hash])
    expect(PhoneNormalizer.from_sha256(sha.upcase, length: 13)[:hash]).to eq(PhoneNormalizer.from_sha256(sha, length: 13)[:hash])
  end

  describe "lookups" do
    before { ReportService.call(reporter, phone: "98765 43210", reason_code: "chargeback", notes: "Disputed 3 card payments") }

    it "finds a report that was filed with the number, using only its SHA-256" do
      post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: 13 }, ctoken
      expect(response).to have_http_status(:ok)
      expect(json).to include("reported" => true, "report_count" => 1, "phone_sha256" => sha, "phone_last4" => nil)
      expect(json["reports"].first["reason_code"]).to eq("chargeback")
    end

    it "answers a batch of hashes in order, echoing each hash" do
      other = Digest::SHA256.hexdigest("+919000000002")
      post_json "/api/v1/lookups/batch", { phone_sha256s: [other, sha], phone_length: 13 }, ctoken
      expect(json["results"].map { |r| [r["phone_sha256"], r["reported"]] }).to eq([[other, false], [sha, true]])
    end

    it "refuses both a number and a hash, a malformed hash, and neither" do
      post_json "/api/v1/lookups", { phone: "9876543210", phone_sha256: sha, phone_length: 13 }, ctoken
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]["message"]).to include("not both")
      post_json "/api/v1/lookups", { phone_sha256: "not-a-hash", phone_length: 13 }, ctoken
      expect([response.status, json["error"]["code"]]).to eq([422, "invalid_phone"])
      expect(json["error"]["message"]).to include("+919876543210")
      post_json "/api/v1/lookups", {}, ctoken
      expect(response).to have_http_status(:unprocessable_entity)
      post_json "/api/v1/lookups/batch", { phones: ["9876543210"], phone_sha256s: [sha], phone_length: 13 }, ctoken
      expect(json["error"]["code"]).to eq("invalid_phones")
    end

    it "charges one check per hash, like a number" do
      expect { post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: 13 }, ctoken }.to change { checker.reload.checks_remaining }.by(-1)
    end
  end

  describe "reports" do
    it "files a report from a hash and its last four digits, and keeps no number" do
      post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, phone_last4: "3210", reason_code: "chargeback" }, rtoken
      expect(response).to have_http_status(:created)
      expect(json["phone_last4"]).to eq("3210")
      report = reporter.fraud_reports.last
      expect(report.phone_ciphertext).to be_nil
      expect(report.phone_hash).to eq(PhoneNormalizer.call("9876543210")[:hash])
    end

    it "is found by a lookup that sends the plain number" do
      post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, phone_last4: "3210", reason_code: "chargeback" }, rtoken
      post_json "/api/v1/lookups", { phone: "98765 43210" }, ctoken
      expect(json).to include("reported" => true, "report_count" => 1)
    end

    it "needs the last four digits with a hash, and they must be digits" do
      post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, reason_code: "chargeback" }, rtoken
      expect([response.status, json["error"]["message"]]).to match([422, /phone_last4/])
      post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, phone_last4: "32x0", reason_code: "chargeback" }, rtoken
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "counts a hashed report and a plain one for the same number as the same report" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, rtoken
      post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, phone_last4: "3210", reason_code: "fake_order" }, rtoken
      expect([response.status, json["error"]["code"]]).to eq([409, "duplicate_report"])
    end

    it "withdraws with a hash, and re-filing as a hash keeps the number already stored" do
      post_json "/api/v1/reports", { phone: "9876543210", reason_code: "chargeback" }, rtoken
      delete "/api/v1/reports", params: { phone_sha256: sha, phone_length: 13 }, as: :json, headers: auth(rtoken)
      expect(json["status"]).to eq("withdrawn")
      post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, phone_last4: "3210", reason_code: "fake_order" }, rtoken
      expect(response).to have_http_status(:created)
      expect(reporter.fraud_reports.last.phone_ciphertext).to eq("+919876543210")
    end

    it "batches a mix of numbers and hashes, each on its own" do
      post_json "/api/v1/reports/batch", { reports: [
        { phone: "9876543210", reason_code: "chargeback" },
        { phone_sha256: Digest::SHA256.hexdigest("+919000000003"), phone_length: 13, phone_last4: "0003", reason_code: "fake_order" },
        { phone_sha256: Digest::SHA256.hexdigest("+919000000004"), phone_length: 13, reason_code: "fake_order" }
      ] }, rtoken
      expect(json["results"].map { |r| r["status"] }).to eq(%w[recorded recorded invalid])
      expect(json["results"][2]["error"]["message"]).to include("phone_last4")
    end
  end

  describe "phone_length: the length of the text that was hashed" do
    it "says what went wrong for the common mistakes" do
      { 10 => /just the ten digits/, 11 => /leading 0/, 12 => /91 plus the ten digits/, 16 => /\+91 followed by ten digits/ }.each do |len, hint|
        post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: len }, ctoken
        expect([response.status, json["error"]["code"]]).to eq([422, "invalid_phone"]), "length #{len}"
        expect(json["error"]["message"]).to include("phone_length must be 13, you sent #{len}").and match(hint)
      end
    end

    it "is required with a hash, and must be a whole number" do
      post_json "/api/v1/lookups", { phone_sha256: sha }, ctoken
      expect(json["error"]["message"]).to include("phone_length is required").and include("13")
      post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: "thirteen" }, ctoken
      expect(json["error"]["message"]).to include("must be 13")
      post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: "13" }, ctoken
      expect(response).to have_http_status(:ok) # a string "13" is fine
    end

    it "is checked once for a batch of lookups, and on every hashed report, withdrawal and batch row" do
      post_json "/api/v1/lookups/batch", { phone_sha256s: [sha] }, ctoken
      expect(json["error"]["message"]).to include("phone_length is required")
      post_json "/api/v1/lookups/batch", { phone_sha256s: [sha], phone_length: 10 }, ctoken
      expect(json["error"]["message"]).to include("you sent 10")
      post_json "/api/v1/reports", { phone_sha256: sha, phone_last4: "3210", phone_length: 12, reason_code: "chargeback" }, rtoken
      expect(response).to have_http_status(:unprocessable_entity)
      delete "/api/v1/reports", params: { phone_sha256: sha, phone_length: 11 }, as: :json, headers: auth(rtoken)
      expect(response).to have_http_status(:unprocessable_entity)
      post_json "/api/v1/reports/batch", { reports: [{ phone_sha256: sha, phone_last4: "3210", reason_code: "chargeback" }] }, rtoken
      expect(json["results"].first["error"]["message"]).to include("phone_length is required")
    end

    it "is not needed when the number itself is sent" do
      post_json "/api/v1/lookups", { phone: "9876543210" }, ctoken
      expect(response).to have_http_status(:ok)
    end

    it "does not charge a check for a request that is refused" do
      expect { post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: 10 }, ctoken }.not_to change { checker.reload.checks_remaining }
    end
  end

  describe "POST /phone_hash/check (a development aid)" do
    it "returns the SHA-256 we compute, says whether yours matches, and costs nothing" do
      expect do
        post_json "/api/v1/phone_hash/check", { phone: "98765 43210", phone_sha256: sha, phone_length: 13 }, ctoken
        expect(json).to include("phone" => number, "phone_sha256" => sha, "phone_length" => 13, "match" => true)
        post_json "/api/v1/phone_hash/check", { phone: "9876543210", phone_sha256: Digest::SHA256.hexdigest("9876543210"), phone_length: 13 }, ctoken
        expect(json).to include("phone_sha256" => sha, "match" => false)
        post_json "/api/v1/phone_hash/check", { phone: "9876543210" }, ctoken
        expect(json["match"]).to be_nil
      end.not_to change { checker.reload.checks_remaining }
    end
  end

  it "keeps hashes and last digits out of the logs, like numbers" do
    path = Rails.root.join("log/#{Rails.env}.log")
    Rails.logger.flush
    before = File.size(path)
    post_json "/api/v1/lookups", { phone_sha256: sha, phone_length: 13 }, ctoken
    post_json "/api/v1/lookups/batch", { phone_sha256s: [sha], phone_length: 13 }, ctoken
    post_json "/api/v1/reports", { phone_sha256: Digest::SHA256.hexdigest("+919000000005"), phone_length: 13, phone_last4: "0005", reason_code: "fake_order" }, rtoken
    Rails.logger.flush
    written = File.open(path) { |f| f.seek(before); f.read }
    expect(written).to include("Processing by")
    expect(written).not_to include(sha)
    expect(written).not_to include(Digest::SHA256.hexdigest("+919000000005"))
  end

  it "shows an admin that a report arrived as a hash only, with its last four digits" do
    admin = AdminUser.create!(email: "a@opentrust.test", password: "adminpassword12")
    post_json "/api/v1/reports", { phone_sha256: sha, phone_length: 13, phone_last4: "3210", reason_code: "chargeback" }, rtoken
    post "/admin/login", params: { email: admin.email, password: "adminpassword12" }
    get "/admin/reports"
    expect(response.body).to include("hash only (••••3210)")
  end
end
