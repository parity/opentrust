# Tells the admins in Slack that a merchant is waiting for approval. Runs after the merchant verifies their email, which is when
# they enter the approval queue. The buttons open the admin page; approving or rejecting happens there, behind the admin login.
class MerchantReviewAlertJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound
  retry_on SlackNotifier::Failed, wait: 30.seconds, attempts: 3

  def perform(merchant_id)
    return unless SlackNotifier.configured?

    merchant = Merchant.find(merchant_id)
    return unless merchant.pending? # approved or rejected in the meantime: nothing to ask
    raise SlackNotifier::Failed unless SlackNotifier.post(text: "New merchant waiting for approval: #{merchant.business_name}", blocks: blocks(merchant))
  end

  private

  def blocks(merchant)
    esc = ->(v) { SlackNotifier.escape(v) }
    host = Rails.application.config.action_mailer.default_url_options
    base = "#{host[:protocol] || 'https'}://#{host[:host]}#{host[:port] ? ":#{host[:port]}" : ''}"
    details = [esc.call(merchant.name), esc.call(merchant.contact_email), esc.call(merchant.website).presence || "no website", merchant.gstin.present? ? "GSTIN given" : "no GSTIN"].join(" · ")
    [
      { type: "section", text: { type: "mrkdwn", text: "*New merchant waiting for approval*\n*#{esc.call(merchant.business_name)}*\n#{details}" } },
      { type: "context", elements: [{ type: "mrkdwn", text: "#{esc.call(host[:host])} · email verified · approving grants #{ActiveSupport::NumberHelper.number_to_delimited(OpenTrust::FREE_CHECKS)} checks" }] },
      { type: "actions", elements: [
        { type: "button", style: "primary", text: { type: "plain_text", text: "Approve or reject" }, url: "#{base}/admin?status=pending#merchant-#{merchant.id}" },
        { type: "button", text: { type: "plain_text", text: "Pending queue" }, url: "#{base}/admin?status=pending" }
      ] }
    ]
  end
end
