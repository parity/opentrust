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
result.reports.each { |r| puts "#{r.reason_code} (#{r.incident_at}): #{r.notes}" }  # other merchants' reports only
result.own_report?     # => true if you have shared this number yourself
result.notice          # keep this in front of anyone who sees the result
result.checks_remaining

client.lookup_many(%w[9876543210 9000000001])          # up to 100, all or nothing
client.report(phone: "9876543210", reason_code: "chargeback", notes: "Disputed 3 card payments in March", incident_at: Date.new(2026, 3, 14),
              confirmed_by: "bank", evidence_ref: "your-ticket-123")   # optional: who confirmed it (shown to others), and a private reference

# up to 100 at once; one bad row never stops the rest
results = client.report_many([{ phone: "9876543210", reason_code: "chargeback", incident_at: "2026-08-14" }, { phone: "9812345678", reason_code: "fake_order" }])
results.reject(&:recorded?).each { |r| warn "row #{r.index}: #{r.status} #{r.error_code}" }

client.withdraw_report("9876543210")                    # take your own report back (raises NotFoundError if there is none)
client.reason_codes                                     # => [#<struct code="chargeback", group=..., label=..., description=...>, ...]
client.me                                               # => { "checks_remaining" => ..., ... }
```

## Send hashes instead of phone numbers

Pass `hash_numbers: true` and the library sends the SHA-256 of each number instead of the number, so OpenTrust never receives it. It also sends `phone_length`, the length of the text it hashed (always 13), which OpenTrust checks to catch a hash of a differently written number. A report also sends the last four digits, so merchants and admins have something to recognise it by.

```ruby
client = OpenTrust::Client.new(hash_numbers: true)
client.lookup("98765 43210")           # sends only the hash and its length (always 13)
OpenTrust.hash_phone("98765 43210")    # => "f3a47ce5ce3d4ca8ad15225a245b2759022f79489f5c62719b8c9490f7aab90e"
client.verify_hashing("98765 43210")   # development aid: asks OpenTrust to compare (sends the number: use a test number)
```

The format is exact, and a hash computed from a differently written number just finds nothing, so use the helper instead of hashing by hand. It is tested against the shared [test vectors](https://github.com/parity/opentrust/blob/main/sdks/phone-hash-vectors.json). A hash of a phone number can in principle be reversed by trying every possible number: this limits what is sent and stored, it does not make a number anonymous.

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

Errors: `AuthenticationError` (401), `NoChecksError` (402, write to us and we'll raise your limit), `NotApprovedError` (403), `NotFoundError` (404, withdrawing a report you don't have), `DuplicateReportError` (409), `InvalidRequestError` (422), `RateLimitError` (429), `ServerError` (5xx), `ConnectionError` (network/timeout). All inherit from `OpenTrust::Error` and carry `status` and `code`.

Timeout defaults to 5 seconds (`timeout:`). Docs: https://opentrust.in/docs

---

Part of [OpenTrust](https://opentrust.in), sponsored by [ParityCube](https://www.paritycube.com/). Source: [github.com/parity/opentrust](https://github.com/parity/opentrust).
