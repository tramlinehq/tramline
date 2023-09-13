class AddTagAllStoreReleasesFlagToTrain < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :trains, bulk: true do |t|
        t.column :tag_platform_releases, :boolean, default: false
        t.column :tag_all_store_releases, :boolean, default: false
      end
    end
  end
end
