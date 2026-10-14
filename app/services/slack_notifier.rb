require "net/http"
require "json"

# Posts to a Slack incoming webhook (SLACK_WEBHOOK_URL). Optional: with no URL it does nothing. Never raises, so a Slack
# problem can never break a request or a job; it returns true or false.
class SlackNotifier
  # Raised by jobs that want Active Job to retry after a failed post.
  class Failed < StandardError; end

  def self.configured? = ENV["SLACK_WEBHOOK_URL"].present?

  def self.post(text:, blocks: nil)
    return true unless configured?

    uri = URI(ENV["SLACK_WEBHOOK_URL"])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 3
    http.read_timeout = 5
    res = http.post(uri.request_uri, { text: text, blocks: blocks }.compact.to_json, "Content-Type" => "application/json")
    res.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.warn("Slack notification failed: #{e.class}")
    false
  end

  # Merchants type these fields, so neutralise Slack's markup: this stops "<!channel>" style mentions and links in what they enter.
  def self.escape(value, max: 200)
    value.to_s.strip.first(max).gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end
end
