class AddNotificationSettingCheck < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :notification_settings, "( (active is true and true = any(ARRAY[core_enabled, release_specific_enabled])) or (active is false and false = all(ARRAY[core_enabled, release_specific_enabled])) )", validate: false
  end
end
