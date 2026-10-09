module Portal
  class BaseController < ApplicationController
    before_action :require_merchant!
    before_action :require_verified_email!
    before_action :require_approved!

    private

    def require_approved! = (render "portal/dashboard/pending" unless current_merchant.approved?)
  end
end
