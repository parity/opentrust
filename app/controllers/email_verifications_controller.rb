class EmailVerificationsController < ApplicationController
  before_action :require_merchant!
  before_action -> { redirect_to portal_root_path if current_merchant_user.email_verified? }

  def show; end

  def create
    case EmailOtp.verify!(current_merchant_user, params[:code])
    when :ok
      session.delete(:dev_otp)
      MerchantMailer.received(current_merchant).deliver_later
      MerchantReviewAlertJob.perform_later(current_merchant.id) # tells the admins in Slack, if a webhook is set
      redirect_to portal_root_path, notice: "Email verified. An admin will review your account shortly."
    when :wrong
      fail_with "That code isn't right. Check the email and try again."
    when :locked
      fail_with "Too many wrong attempts. Request a new code."
    else
      fail_with "That code has expired. Request a new one."
    end
  end

  def resend
    code = EmailOtp.issue!(current_merchant_user)
    session[:dev_otp] = code if Rails.env.development?
    redirect_to verify_email_path, notice: "New code sent to #{current_merchant_user.email}."
  rescue EmailOtp::TooSoon, EmailOtp::TooMany => e
    redirect_to verify_email_path, alert: e.message
  rescue StandardError => e
    Rails.logger.error("OTP email failed for merchant_user #{current_merchant_user.id}: #{e.class}: #{e.message}")
    redirect_to verify_email_path, alert: "We couldn't send the email just now. Please try again in a minute."
  end

  private

  def fail_with(message)
    flash.now[:alert] = message
    render :show, status: :unprocessable_entity
  end
end
