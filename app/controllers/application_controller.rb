class ApplicationController < ActionController::Base
  helper_method :current_merchant_user, :current_merchant

  private

  def current_merchant_user = @current_merchant_user ||= MerchantUser.find_by(id: session[:merchant_user_id])
  def current_merchant = current_merchant_user&.merchant
  def require_merchant! = (redirect_to login_path, alert: "Please log in" unless current_merchant_user)
  def require_verified_email!
    return if current_merchant_user.email_verified?
    redirect_to verify_email_path, alert: "Please verify your email to continue."
  end
end
