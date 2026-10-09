require "json"
require "net/http"
require "uri"

module OpenTrust
  Report = Struct.new(:reason_code, :reason, :notes, :reported_at, :reporter_verified, keyword_init: true)

  # The result of checking one number. Reports are unverified observations from individual merchants,
  # not a finding about anyone. Use them as one input among others.
  Lookup = Struct.new(:phone_last4, :report_count, :reports, :notice, :checks_remaining, keyword_init: true) do
    def reported?
      report_count.to_i.positive?
    end
  end

  Receipt = Struct.new(:id, :phone_last4, keyword_init: true)

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
    def report(phone:, reason_code:, notes: nil)
      body = request(:post, "/reports", { phone: phone, reason_code: reason_code, notes: notes }.compact)
      Receipt.new(id: body["id"], phone_last4: body["phone_last4"])
    end

    # Your remaining checks and usage, as a Hash.
    def me
      request(:get, "/me")
    end

    private

    def lookup_from(h)
      Lookup.new(
        phone_last4: h["phone_last4"], report_count: h["report_count"], notice: h["notice"], checks_remaining: h["checks_remaining"],
        reports: Array(h["reports"]).map { |r| Report.new(reason_code: r["reason_code"], reason: r["reason"], notes: r["notes"], reported_at: r["reported_at"], reporter_verified: r["reporter_verified"]) }
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
      klass = verb == :get ? Net::HTTP::Get : Net::HTTP::Post
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
