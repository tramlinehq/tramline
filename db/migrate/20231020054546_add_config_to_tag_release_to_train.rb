class AddConfigToTagReleaseToTrain < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :trains, bulk: true do |t|
        t.column :tag_releases, :boolean, default: true
        t.column :tag_suffix, :string
      end
    end
  end
end
