module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin!
    helper_method :current_admin

    private

    def current_admin = @current_admin ||= AdminUser.find_by(id: session[:admin_user_id])
    def require_admin! = (redirect_to admin_login_path unless current_admin)
  end
end
