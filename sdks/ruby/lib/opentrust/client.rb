require "json"
require "net/http"
require "uri"

module OpenTrust
  Report = Struct.new(:reason_code, :reason, :notes, :incident_at, :confirmed_by, :reported_at, :reporter_verified, keyword_init: true)

  # The result of checking one number. Reports are unverified observations from individual merchants,
  # not a finding about anyone. Use them as one input among others.
  #
  # `reports` and `report_count` only hold OTHER merchants' reports. `own_report` says whether you have shared this number yourself.
  Lookup = Struct.new(:phone_last4, :report_count, :reports, :own_report, :notice, :checks_remaining, keyword_init: true) do
    def reported?
      report_count.to_i.positive?
    end

    def own_report?
      own_report == true
    end
  end

  Receipt = Struct.new(:id, :phone_last4, keyword_init: true)

  # One row of a bulk report. `status` is "recorded", "duplicate" (you already shared it; treat as done) or "invalid".
  BatchResult = Struct.new(:index, :status, :id, :phone_last4, :error_code, :error_message, keyword_init: true) do
    def recorded?
      status == "recorded"
    end

    def duplicate?
      status == "duplicate"
    end

    def invalid?
      status == "invalid"
    end
  end

  Withdrawal = Struct.new(:phone_last4, :status, keyword_init: true)
  ReasonCode = Struct.new(:code, :group, :label, :description, :use_when, :not_when, keyword_init: true)

  class Client
    DEFAULT_BASE_URL = "https://opentrust.in/api/v1".freeze

    # adapter: optional callable (method, url, headers, body) -> [status, body_string], mainly for tests.
    def initialize(api_key: ENV["OPENTRUST_API_KEY"], base_url: ENV.fetch("OPENTRUST_BASE_URL", DEFAULT_BASE_URL), timeout: 5, adapter: nil)
      raise ArgumentError, "api_key is required (or set OPENTRUST_API_KEY)" if api_key.to_s.empty?

      @api_key = api_key
      @base_url = base_url.chomp("/")
      @timeout = timeout
      @adapter = adapter
    end

    # Check one number. Uses one check from your allowance.
    def lookup(phone)
      lookup_from(request(:post, "/lookups", phone: phone))
    end

    # Check up to 100 numbers. All or nothing: if you don't have enough checks, none are used.
    def lookup_many(phones)
      body = request(:post, "/lookups/batch", phones: Array(phones))
      body.fetch("results").map { |r| lookup_from(r.merge("notice" => body["notice"], "checks_remaining" => body["checks_remaining"])) }
    end

    # Share an experience with a number. Optional, and doesn't change your allowance.
    # incident_at: when it happened (a Date, a Time or an ISO 8601 string); can't be in the future.
    # confirmed_by: "bank", "payment_gateway" or "law_enforcement", only if they told you the activity was confirmed (shown to other
    # merchants, not verified). evidence_ref: a private reference for administrators, never shown; needs confirmed_by.
    def report(phone:, reason_code:, notes: nil, incident_at: nil, confirmed_by: nil, evidence_ref: nil)
      body = request(:post, "/reports", report_payload(phone: phone, reason_code: reason_code, notes: notes, incident_at: incident_at,
                                                       confirmed_by: confirmed_by, evidence_ref: evidence_ref))
      Receipt.new(id: body["id"], phone_last4: body["phone_last4"])
    end

    # Share up to 100 experiences at once. Each is handled on its own, so one bad row never stops the rest: the result is a
    # BatchResult per report, in order. reports: [{ phone:, reason_code:, notes:, incident_at: }, ...]
    def report_many(reports)
      list = Array(reports)
      raise ArgumentError, "report_many takes 1 to 100 reports" unless list.size.between?(1, 100)

      body = request(:post, "/reports/batch", reports: list.map { |r| report_payload(**r.transform_keys(&:to_sym)) })
      body.fetch("results").map do |r|
        BatchResult.new(index: r["index"], status: r["status"], id: r["id"], phone_last4: r["phone_last4"],
                        error_code: r.dig("error", "code"), error_message: r.dig("error", "message"))
      end
    end

    # Withdraw your own report for a number. Raises NotFoundError if you have no active report for it.
    def withdraw_report(phone)
      body = request(:delete, "/reports", phone: phone)
      Withdrawal.new(phone_last4: body["phone_last4"], status: body["status"])
    end

    # The reason codes with their labels and descriptions.
    def reason_codes
      request(:get, "/reason_codes").fetch("reason_codes").map { |c| ReasonCode.new(code: c["code"], group: c["group"], label: c["label"], description: c["description"], use_when: c["use_when"], not_when: c["not_when"]) }
    end

    # Your remaining checks and usage, as a Hash.
    def me
      request(:get, "/me")
    end

    private

    def report_payload(phone:, reason_code:, notes: nil, incident_at: nil, confirmed_by: nil, evidence_ref: nil)
      incident_at = incident_at.iso8601 if incident_at.respond_to?(:iso8601)
      { phone: phone, reason_code: reason_code, notes: notes, incident_at: incident_at, confirmed_by: confirmed_by, evidence_ref: evidence_ref }.compact
    end

    def lookup_from(h)
      Lookup.new(
        phone_last4: h["phone_last4"], report_count: h["report_count"], own_report: h["own_report"], notice: h["notice"], checks_remaining: h["checks_remaining"],
        reports: Array(h["reports"]).map do |r|
          Report.new(reason_code: r["reason_code"], reason: r["reason"], notes: r["notes"], incident_at: r["incident_at"], confirmed_by: r["confirmed_by"], reported_at: r["reported_at"], reporter_verified: r["reporter_verified"])
        end
      )
    end

    def request(verb, path, payload = nil)
      headers = { "Authorization" => "Bearer #{@api_key}", "Accept" => "application/json", "User-Agent" => "opentrust-ruby/#{VERSION}" }
      headers["Content-Type"] = "application/json" if payload
      status, text = perform(verb, "#{@base_url}#{path}", headers, payload && JSON.generate(payload))
      body = begin JSON.parse(text.to_s) rescue {} end
      raise_for(status, body) unless (200..299).cover?(status)
      body
    end

    def perform(verb, url, headers, body)
      return @adapter.call(verb, url, headers, body) if @adapter

      uri = URI(url)
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(verb)
      req = klass.new(uri, headers)
      req.body = body if body
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: @timeout, read_timeout: @timeout) { |http| http.request(req) }
      [res.code.to_i, res.body]
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, EOFError => e
      raise ConnectionError.new("could not reach OpenTrust: #{e.class}: #{e.message}")
    end

    def raise_for(status, body)
      err = body["error"].is_a?(Hash) ? body["error"] : {}
      message = err["message"] || "OpenTrust returned HTTP #{status}"
      klass = case status
              when 401 then AuthenticationError
              when 402 then NoChecksError
              when 403 then NotApprovedError
              when 404 then NotFoundError
              when 409 then DuplicateReportError
              when 422 then InvalidRequestError
              when 429 then RateLimitError
              when 500..599 then ServerError
              else Error
              end
      raise klass.new(message, status: status, code: err["code"])
    end
  end
end
