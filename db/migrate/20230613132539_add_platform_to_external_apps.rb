class AddPlatformToExternalApps < ActiveRecord::Migration[7.0]
  def change
    add_column :external_apps, :platform, :string
  end
end
