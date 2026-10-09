# opentrust (Ruby)

Check mobile numbers against experiences shared by other Indian merchants, and share your own. No dependencies.

```ruby
# Gemfile
gem "opentrust"
```

```ruby
require "opentrust"

client = OpenTrust::Client.new(api_key: ENV["OPENTRUST_API_KEY"]) # or just set OPENTRUST_API_KEY

result = client.lookup("98765 43210")   # uses 1 check
result.reported?       # => true / false
result.report_count    # => 2
result.reports.each { |r| puts "#{r.reason_code}: #{r.notes}" }
result.notice          # keep this in front of anyone who sees the result
result.checks_remaining

client.lookup_many(%w[9876543210 9000000001])          # up to 100, all or nothing
client.report(phone: "9876543210", reason_code: "cod_refusal", notes: "Refused 3 COD orders in March")
client.me                                               # => { "checks_remaining" => ..., ... }
```

## Please don't block checkout on OpenTrust

Results are unverified observations from individual merchants. Use them as one input, have a person review decisions that matter, and fail open if OpenTrust is unreachable:

```ruby
begin
  result = client.lookup(order.phone)
  flag_for_review(order) if result.reported?
rescue OpenTrust::Error => e
  Rails.logger.warn("OpenTrust unavailable: #{e.message}") # carry on
end
```

Errors: `AuthenticationError` (401), `NoChecksError` (402, write to us and we'll raise your limit), `NotApprovedError` (403), `DuplicateReportError` (409), `InvalidRequestError` (422), `RateLimitError` (429), `ServerError` (5xx), `ConnectionError` (network/timeout). All inherit from `OpenTrust::Error` and carry `status` and `code`.

Timeout defaults to 5 seconds (`timeout:`). Docs: https://opentrust.in/docs
