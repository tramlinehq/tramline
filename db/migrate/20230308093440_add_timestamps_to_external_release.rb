class AddTimestampsToExternalRelease < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :external_releases, bulk: true do |t|
        t.column :reviewed_at, :datetime
        t.column :released_at, :datetime
      end
    end
  end
end
