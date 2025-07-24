class AddUserContentToNotificationSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :notification_settings, :user_content, :text
  end
end
