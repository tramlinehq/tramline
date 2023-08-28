class AddAppDraftFlag < ActiveRecord::Migration[7.0]
  def change
    add_column :apps, :draft, :boolean
  end
end
