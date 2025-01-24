class AddRetryFieldsForStoreSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :store_submissions, :last_stable_status, :string
  end
end
