require "rails_helper"
require "socket"

RSpec.describe MerchantReviewAlertJob, type: :request do
  # A tiny real HTTP server standing in for Slack, so the actual POST is exercised.
  def with_slack(status: 200)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    requests = Queue.new
    thread = Thread.new do
      loop do
        client = server.accept
        head = +""
        head << client.gets until head.end_with?("\r\n\r\n") || head.empty? && false
        length = head[/content-length: (\d+)/i, 1].to_i
        requests << { head: head, body: client.read(length) }
        client.write "HTTP/1.1 #{status} X\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
        client.close
      rescue IOError
        break
      end
    end
    ENV["SLACK_WEBHOOK_URL"] = "http://127.0.0.1:#{port}/services/T/B/secret"
    yield requests
  ensure
    ENV.delete("SLACK_WEBHOOK_URL")
    thread&.kill
    server&.close
  end

  let(:merchant) { create(:merchant, status: "pending", business_name: "Rao Handloom", name: "Asha Rao", website: "https://raohandloom.example", gstin: "27ABCDE1234F1Z5") }

  it "posts who is waiting, with buttons that open the admin queue at that merchant" do
    with_slack do |requests|
      described_class.perform_now(merchant.id)
      req = requests.pop
      expect(req[:head]).to start_with("POST /services/T/B/secret")
      body = JSON.parse(req[:body])
      expect(body["text"]).to eq("New merchant waiting for approval: Rao Handloom")
      text = body["blocks"].first["text"]["text"]
      expect(text).to include("*Rao Handloom*", "Asha Rao", merchant.contact_email, "https://raohandloom.example", "GSTIN given")
      buttons = body["blocks"].last["elements"]
      expect(buttons.map { |b| b["url"] }).to eq(["https://opentrust.test/admin?status=pending#merchant-#{merchant.id}", "https://opentrust.test/admin?status=pending"])
      expect(buttons.first["text"]["text"]).to eq("Approve or reject")
      expect(body.to_s).not_to include(merchant.merchant_user&.password_digest.to_s) if merchant.merchant_user
    end
  end

  it "neutralises Slack markup in what a merchant typed, so it cannot ping the channel or add links" do
    evil = create(:merchant, status: "pending", business_name: "<!channel> Click <https://evil.example|here> & win", name: "<!here>")
    with_slack do |requests|
      described_class.perform_now(evil.id)
      text = JSON.parse(requests.pop[:body])["blocks"].first["text"]["text"]
      expect(text).to include("&lt;!channel&gt;", "&lt;https://evil.example|here&gt;", "&amp; win", "&lt;!here&gt;")
      expect(text).not_to include("<!channel>")
      expect(text).not_to include("<!here>")
    end
  end

  it "does nothing without a webhook, and nothing when the merchant is no longer pending" do
    expect(SlackNotifier).not_to receive(:post)
    described_class.perform_now(merchant.id)
    ENV["SLACK_WEBHOOK_URL"] = "http://127.0.0.1:9/x"
    merchant.update!(status: "approved")
    described_class.perform_now(merchant.id)
  ensure
    ENV.delete("SLACK_WEBHOOK_URL")
  end

  it "retries later when Slack answers with an error, and the notifier itself never raises" do
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    with_slack(status: 500) do
      expect { described_class.perform_now(merchant.id) }.to have_enqueued_job(described_class).with(merchant.id)
    end
    ENV["SLACK_WEBHOOK_URL"] = "http://127.0.0.1:1/unreachable"
    expect(SlackNotifier.post(text: "x")).to be(false)
  ensure
    ActiveJob::Base.queue_adapter = original
    ENV.delete("SLACK_WEBHOOK_URL")
  end

  it "is queued when a merchant verifies their email" do
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    post "/register", params: { merchant: { business_name: "Acme", name: "Jo", contact_email: "v@acme.test", phone: "9876543210" }, password: "supersecret", accept_terms: "1" }
    user = MerchantUser.find_by!(email: "v@acme.test")
    code = ActionMailer::Base.deliveries.last.text_part.body.decoded[/\b\d{6}\b/]
    expect { post "/verify-email", params: { code: code } }.to have_enqueued_job(described_class).with(user.merchant_id)
  ensure
    ActiveJob::Base.queue_adapter = original
  end
end
