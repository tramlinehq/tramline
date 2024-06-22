class AddProductionRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :production_releases do |t|
      t.belongs_to :build, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    safety_assured do
      change_table :store_submissions do |t|
        t.belongs_to :production_release, foreign_key: true
      end
    end
  end
end
