module Portal
  class ApiKeysController < BaseController
    def index = (@keys = current_merchant.api_keys.order(id: :desc))

    def create
      _key, @token = ApiKey.issue!(current_merchant, label: params[:label].presence)
      @keys = current_merchant.api_keys.order(id: :desc)
      render :index
    end

    def destroy
      current_merchant.api_keys.find(params[:id]).revoke!
      redirect_to portal_api_keys_path, notice: "Key revoked"
    end
  end
end
