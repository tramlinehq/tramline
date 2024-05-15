class AddStoreSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :store_submissions, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.references :build, null: true, index: true, foreign_key: true, type: :uuid

      t.string :status, null: false
      t.string :name
      t.string :type, null: false
      t.string :failure_reason
      t.timestamp :prepared_at
      t.timestamp :submitted_at
      t.timestamp :rejected_at
      t.timestamp :approved_at
      t.string :store_link
      t.string :store_status
      t.timestamps
    end
  end
end
