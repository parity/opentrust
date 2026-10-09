class AuditLog < ApplicationRecord
  belongs_to :admin_user, optional: true
  def self.record(admin, action, target = nil, details = {})
    create!(admin_user: admin, action: action, target_type: target&.class&.name, target_id: target&.id, details: details)
  end
end
