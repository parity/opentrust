class RegistrationsController < ApplicationController
  def new = (@merchant = Merchant.new)

  def create
    @merchant = Merchant.new(params.require(:merchant).permit(:name, :business_name, :website, :gstin, :contact_email, :phone))
    user = @merchant.build_merchant_user(email: @merchant.contact_email, password: params[:password], password_confirmation: params[:password])
    unless params[:accept_terms] == "1"
      @merchant.errors.add(:base, "Please accept the Terms and the Privacy Policy to continue")
      flash.now[:alert] = @merchant.errors.full_messages.to_sentence
      return render :new, status: :unprocessable_entity
    end
    @merchant.assign_attributes(terms_accepted_at: Time.current, terms_version: OpenTrust::LEGAL_VERSION, terms_accepted_ip: request.remote_ip)
    if @merchant.save
      reset_session
      session[:merchant_user_id] = user.id
      begin
        code = EmailOtp.issue!(user)
        session[:dev_otp] = code if Rails.env.development?
      rescue EmailOtp::TooSoon, EmailOtp::TooMany
        nil
      rescue StandardError => e
        Rails.logger.error("OTP email failed for merchant_user #{user.id}: #{e.class}: #{e.message}")
        flash[:alert] = "We couldn't send the email just now. Tap \"Send a new code\" in a moment."
        return redirect_to(verify_email_path)
      end
      redirect_to verify_email_path, notice: "We've emailed a 6-digit code to #{user.email}."
    else
      flash.now[:alert] = (@merchant.errors.full_messages + user.errors.full_messages).uniq.to_sentence
      render :new, status: :unprocessable_entity
    end
  end
end
