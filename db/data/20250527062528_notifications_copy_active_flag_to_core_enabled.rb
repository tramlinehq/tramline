# frozen_string_literal: true

class NotificationsCopyActiveFlagToCoreEnabled < ActiveRecord::Migration[7.2]
  def up
    # Update core_enabled flag for notifications which are currently active
    NotificationSetting.where(active: true).update_all(core_enabled: true)

    # Turn on the global-active flag for notifications where release specific is enabled but the core notification is disabled
    # core_enabled is false by default, no need to update it.
    NotificationSetting.where(active: false, release_specific_enabled: true).update_all(active: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
