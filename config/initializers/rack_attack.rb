class Rack::Attack
  # Per API key (falls back to IP for unauthenticated traffic).
  throttle("api/key", limit: 120, period: 1.minute) do |req|
    next unless req.path.start_with?("/api/")
    req.get_header("HTTP_AUTHORIZATION").presence || req.ip
  end

  throttle("verify-email/ip", limit: 15, period: 10.minutes) do |req|
    req.ip if req.path.start_with?("/verify-email") && req.post?
  end

  throttle("register/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/register" && req.post?
  end

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "application/json" }, [{ error: { code: "rate_limited", message: "Too many requests. Please slow down and try again shortly." } }.to_json]]
  end
end
