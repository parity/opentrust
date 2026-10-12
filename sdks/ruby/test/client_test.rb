require "minitest/autorun"
require "date"
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

  def test_lookup_reads_own_report_and_incident_date
    body = { "phone_last4" => "3210", "report_count" => 1, "own_report" => true, "reports" => [{ "reason_code" => "chargeback", "incident_at" => "2026-08-14", "reported_at" => "2026-10-01" }] }
    result = client(body: body).lookup("9876543210")
    assert result.own_report?
    assert_equal "2026-08-14", result.reports.first.incident_at
    refute client(body: { "report_count" => 0, "reports" => [] }).lookup("9000000001").own_report?
  end

  def test_report_sends_incident_at_as_iso8601
    seen = nil
    client(status: 201, body: { "id" => 1, "phone_last4" => "3210" }) { |_v, _u, _h, b| seen = JSON.parse(b) }
      .report(phone: "9876543210", reason_code: "chargeback", incident_at: Date.new(2026, 8, 14))
    assert_equal "2026-08-14", seen["incident_at"]
  end

  def test_report_sends_confirmation_and_lookup_reads_it
    seen = nil
    client(status: 201, body: { "id" => 1, "phone_last4" => "3210" }) { |_v, _u, _h, b| seen = JSON.parse(b) }
      .report(phone: "9876543210", reason_code: "chargeback", confirmed_by: "payment_gateway", evidence_ref: "GW-1")
    assert_equal({ "confirmed_by" => "payment_gateway", "evidence_ref" => "GW-1" }, seen.slice("confirmed_by", "evidence_ref"))
    refute_includes seen.keys, "notes"
    result = client(body: { "report_count" => 1, "reports" => [{ "reason_code" => "chargeback", "confirmed_by" => "bank" }] }).lookup("9876543210")
    assert_equal "bank", result.reports.first.confirmed_by
  end

  def test_report_many_maps_each_result
    body = { "results" => [{ "index" => 0, "status" => "recorded", "id" => 5, "phone_last4" => "3210" },
                           { "index" => 1, "status" => "duplicate", "error" => { "code" => "duplicate_report", "message" => "dup" } },
                           { "index" => 2, "status" => "invalid", "error" => { "code" => "invalid_phone", "message" => "bad" } }] }
    seen = nil
    results = client(body: body) { |v, u, _h, b| seen = [v, u, JSON.parse(b)] }
              .report_many([{ phone: "9876543210", reason_code: "chargeback", incident_at: Date.new(2026, 8, 14) }, { "phone" => "9812345678", "reason_code" => "fake_order" }, { phone: "1", reason_code: "x" }])
    assert_equal [:post, "https://opentrust.in/api/v1/reports/batch"], seen[0, 2]
    assert_equal "2026-08-14", seen[2]["reports"][0]["incident_at"]
    assert_equal [true, false, false], results.map(&:recorded?)
    assert results[1].duplicate?
    assert_equal "invalid_phone", results[2].error_code
    assert_raises(ArgumentError) { client.report_many([]) }
    assert_raises(ArgumentError) { client.report_many(Array.new(101) { { phone: "9876543210", reason_code: "chargeback" } }) }
  end

  def test_withdraw_report_sends_delete_and_raises_not_found
    seen = nil
    w = client(body: { "phone_last4" => "3210", "status" => "withdrawn" }) { |v, u, _h, b| seen = [v, u, JSON.parse(b)] }.withdraw_report("9876543210")
    assert_equal [:delete, "https://opentrust.in/api/v1/reports", { "phone" => "9876543210" }], seen
    assert_equal "withdrawn", w.status
    err = assert_raises(OpenTrust::NotFoundError) { client(status: 404, body: { "error" => { "code" => "report_not_found", "message" => "none" } }).withdraw_report("9876543210") }
    assert_equal "report_not_found", err.code
  end

  def test_reason_codes
    codes = client(body: { "reason_codes" => [{ "code" => "chargeback", "group" => "Orders and payments", "label" => "Disputed a payment (chargeback)", "description" => "d.", "use_when" => "u", "not_when" => "n" }] }).reason_codes
    assert_equal ["chargeback"], codes.map(&:code)
    assert_equal "Orders and payments", codes.first.group
    assert_equal ["u", "n"], [codes.first.use_when, codes.first.not_when]
  end

  def test_errors_are_typed
    { 401 => OpenTrust::AuthenticationError, 402 => OpenTrust::NoChecksError, 403 => OpenTrust::NotApprovedError, 404 => OpenTrust::NotFoundError,
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
