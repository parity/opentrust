module Admin
  class AuditLogsController < BaseController
    def index = (@logs = AuditLog.order(id: :desc).limit(200))
  end
end
