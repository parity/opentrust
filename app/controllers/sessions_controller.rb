class SessionsController < ApplicationController
  def new; end

  def create
    user = MerchantUser.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      reset_session
      session[:merchant_user_id] = user.id
      redirect_to portal_root_path
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy = (reset_session; redirect_to root_path)
end
