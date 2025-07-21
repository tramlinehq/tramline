class AddEnableChangelogLinkingInNotificationsToTrains < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :enable_changelog_linking_in_notifications, :boolean, default: false
  end
end
