class MoveReleaseHealthRulesToPlatformLevel < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :release_health_rules, bulk: true do |t|
        t.belongs_to :release_platform, null: false, index: true, foreign_key: true, type: :uuid
        t.remove :train_id
      end
    end
  end
end
