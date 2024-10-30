class AddApprovals < ActiveRecord::Migration[7.2]
  def change
    create_table :approval_items do |t|
      t.string :content, null: false
      t.string :status, default: "not_started"
      t.datetime :status_changed_at, null: true, index: true
      t.references :status_changed_by, null: true, foreign_key: {to_table: :users}, type: :uuid
      t.references :author, null: false, foreign_key: {to_table: :users}, type: :uuid
      t.belongs_to :release, null: false, foreign_key: true, index: true, type: :uuid

      t.timestamps
    end

    create_table :approval_assignees do |t|
      t.belongs_to :approval_item, null: false, foreign_key: true, index: true
      t.belongs_to :assignee, null: false, foreign_key: {to_table: :users}, type: :uuid

      t.timestamps
    end

    safety_assured do
      add_column :trains, :approvals_enabled, :boolean, default: false, null: false
      add_belongs_to :releases, :approval_overridden_by, null: true, foreign_key: {to_table: :users}, type: :uuid
    end
  end
end
