module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin!, only: %i[new create]
    layout "application"

    def new; end

    def create
      admin = AdminUser.find_by(email: params[:email].to_s.strip.downcase)
      if admin&.authenticate(params[:password])
        reset_session
        session[:admin_user_id] = admin.id
        redirect_to admin_root_path
      else
        flash.now[:alert] = "Invalid credentials"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy = (reset_session; redirect_to admin_login_path)
  end
end
