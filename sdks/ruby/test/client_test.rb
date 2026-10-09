require "minitest/autorun"
require_relative "../lib/opentrust"

class ClientTest < Minitest::Test
  def client(status: 200, body: {}, &capture)
    adapter = lambda do |verb, url, headers, req_body|
      capture&.call(verb, url, headers, req_body)
      [status, JSON.generate(body)]
    end
    OpenTrust::Client.new(api_key: "ot_live_test", adapter: adapter)
  end

  def test_lookup_with_reports
    body = { "phone_last4" => "3210", "reported" => true, "report_count" => 1, "notice" => "Unverified…", "checks_remaining" => 99,
             "reports" => [{ "reason_code" => "cod_refusal", "notes" => "Refused 3 COD orders", "reported_at" => "2026-10-01", "reporter_verified" => true }] }
    seen = nil
    result = client(body: body) { |v, u, h, b| seen = [v, u, h, b] }.lookup("98765 43210")
    assert result.reported?
    assert_equal 1, result.report_count
    assert_equal "cod_refusal", result.reports.first.reason_code
    assert_equal 99, result.checks_remaining
    assert_equal :post, seen[0]
    assert_equal "https://opentrust.in/api/v1/lookups", seen[1]
    assert_equal "Bearer ot_live_test", seen[2]["Authorization"]
    assert_equal({ "phone" => "98765 43210" }, JSON.parse(seen[3]))
  end

  def test_lookup_with_no_reports
    result = client(body: { "phone_last4" => "0001", "report_count" => 0, "reports" => [] }).lookup("9000000001")
    refute result.reported?
    assert_empty result.reports
  end

  def test_lookup_many_shares_notice_and_balance
    body = { "results" => [{ "phone_last4" => "1", "report_count" => 0, "reports" => [] }, { "phone_last4" => "2", "report_count" => 2, "reports" => [] }],
             "notice" => "N", "checks_remaining" => 5 }
    results = client(body: body).lookup_many(%w[9000000001 9000000002])
    assert_equal [false, true], results.map(&:reported?)
    assert_equal ["N", "N"], results.map(&:notice)
  end

  def test_report_omits_nil_notes
    seen = nil
    receipt = client(status: 201, body: { "id" => 7, "phone_last4" => "3210", "status" => "recorded" }) { |_v, _u, _h, b| seen = b }
              .report(phone: "9876543210", reason_code: "cod_refusal")
    assert_equal 7, receipt.id
    refute_includes JSON.parse(seen), "notes"
  end

  def test_errors_are_typed
    { 401 => OpenTrust::AuthenticationError, 402 => OpenTrust::NoChecksError, 403 => OpenTrust::NotApprovedError,
      409 => OpenTrust::DuplicateReportError, 422 => OpenTrust::InvalidRequestError, 429 => OpenTrust::RateLimitError,
      503 => OpenTrust::ServerError }.each do |status, klass|
      err = assert_raises(klass) { client(status: status, body: { "error" => { "code" => "x", "message" => "boom" } }).lookup("9876543210") }
      assert_equal status, err.status
      assert_equal "boom", err.message
      assert_kind_of OpenTrust::Error, err
    end
  end

  def test_requires_api_key
    assert_raises(ArgumentError) { OpenTrust::Client.new(api_key: "") }
  end
end
