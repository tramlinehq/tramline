class AddSubscriberToOrgs < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :subscribed, :boolean, default: false
  end
end
