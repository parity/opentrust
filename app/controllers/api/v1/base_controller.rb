module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!

      rescue_from PhoneNormalizer::Invalid do |e| render_error(422, "invalid_phone", e.message) end
      rescue_from Checks::Ledger::Insufficient do render_error(402, "no_checks_remaining", "You have used all your checks. Write to #{OpenTrust::FEEDBACK_EMAIL} and we will raise your limit.") end
      rescue_from ReportService::Duplicate do |e| render_error(409, "duplicate_report", e.message) end
      rescue_from ActiveRecord::RecordInvalid do |e| render_error(422, "invalid_report", e.record.errors.full_messages.to_sentence) end
      rescue_from ActionController::ParameterMissing do |e| render_error(422, "missing_param", e.message) end

      private

      attr_reader :current_merchant

      def authenticate!
        token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        key = ApiKey.authenticate(token)
        return render_error(401, "invalid_api_key", "Missing or invalid API key") unless key
        return render_error(403, "merchant_not_approved", "Merchant account is not approved") unless key.merchant.approved?
        key.touch(:last_used_at) if key.last_used_at.nil? || key.last_used_at < 1.minute.ago
        @current_merchant = key.merchant
        request.env["opentrust.api_key_id"] = key.id
      end

      def render_error(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end

      def checks_remaining = current_merchant.reload.checks_remaining
    end
  end
end
