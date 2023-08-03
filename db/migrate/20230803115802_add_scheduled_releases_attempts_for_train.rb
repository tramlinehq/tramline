class AddScheduledReleasesAttemptsForTrain < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_releases, id: :uuid do |t|
      t.belongs_to :train, null: false, index: true, foreign_key: true, type: :uuid

      t.boolean :is_success, default: false
      t.string :failure_reason
      t.datetime :scheduled_at, null: false

      t.timestamps
    end
  end
end
