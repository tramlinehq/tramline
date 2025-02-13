class Current < ActiveSupport::CurrentAttributes
  attribute :organization, :user, :app_id
end
