class CreateForwardMergeQueue < ActiveRecord::Migration[7.2]
  def change
    create_table :forward_merge_queues, id: :uuid do |t|
      t.references :release, type: :uuid, null: false, foreign_key: true, index: true
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
  end
end
