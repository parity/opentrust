require "rails_helper"

# Rails logs request parameters. Numbers that are only checked are not stored, so they must not leak into the logs either.
RSpec.describe "Logs never contain phone numbers or notes", type: :request do
  let(:merchant) { create(:merchant, checks_remaining: 20) }
  let(:token) { ApiKey.issue!(merchant).last }
  let(:number) { "9876543210" }

  def log_written_by
    Rails.logger.flush
    path = Rails.root.join("log/#{Rails.env}.log")
    before = File.size(path)
    yield
    Rails.logger.flush
    File.open(path) { |f| f.seek(before); f.read }
  end

  it "filters phone, notes, evidence and email from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    out = filter.filter("phone" => number, "lookup" => { "phone" => number }, "phones" => [number],
                        "notes" => "Refused 3 orders", "evidence_ref" => "BANK-REF-1", "email" => "a@b.test", "reason_code" => "chargeback")
    expect(out.to_s).not_to match(/#{number}|Refused 3|BANK-REF|a@b\.test/)
    expect(out["reason_code"]).to eq("chargeback")
  end

  it "writes nothing identifying to the log for a lookup, a batch lookup and a report" do
    written = log_written_by do
      post "/api/v1/lookups", params: { phone: number }, as: :json, headers: { "Authorization" => "Bearer #{token}" }
      post "/api/v1/lookups/batch", params: { phones: [number, "9123456780"] }, as: :json, headers: { "Authorization" => "Bearer #{token}" }
      post "/api/v1/reports", params: { phone: "9123456781", reason_code: "chargeback", notes: "Disputed 3 card payments" }, as: :json, headers: { "Authorization" => "Bearer #{token}" }
    end
    expect(written).to include("Processing by")      # the requests really were logged...
    expect(written).not_to match(/9876543210|9123456780|9123456781|Disputed 3 card/) # ...without the numbers or notes
  end
end
