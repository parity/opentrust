module OpenTrust
  # Base class. Rescue this to handle anything that goes wrong talking to OpenTrust.
  class Error < StandardError
    attr_reader :status, :code

    def initialize(message = nil, status: nil, code: nil)
      super(message)
      @status = status
      @code = code
    end
  end

  class ConnectionError < Error; end        # network failure or timeout
  class AuthenticationError < Error; end    # 401: missing or invalid API key
  class NoChecksError < Error; end          # 402: allowance used up
  class NotApprovedError < Error; end       # 403: account not approved or suspended
  class NotFoundError < Error; end          # 404: no active report of yours for that number (withdrawing)
  class DuplicateReportError < Error; end   # 409: you already shared this number
  class InvalidRequestError < Error; end    # 422: bad number, reason code or note
  class RateLimitError < Error; end         # 429
  class ServerError < Error; end            # 5xx
end
