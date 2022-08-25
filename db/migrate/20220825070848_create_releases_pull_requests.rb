class CreateReleasesPullRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :releases_pull_requests, id: :uuid do |t|
      t.references :train_run, null: false, index: true, foreign_key: true, type: :uuid
      t.bigint :number, null: false
      t.string :source_id, null: false
      t.string :url
      t.string :title, null: false
      t.text :body
      t.string :state, null: false
      t.string :phase, null: false
      t.string :source, null: false
      t.string :head_ref, null: false
      t.string :base_ref, null: false
      t.datetime :opened_at, null: false
      t.datetime :closed_at

      t.timestamps
    end

    add_index :releases_pull_requests, :number
    add_index :releases_pull_requests, :source_id
    add_index :releases_pull_requests, :state
    add_index :releases_pull_requests, :phase
    add_index :releases_pull_requests, :source
    add_index :releases_pull_requests, [:train_run_id, :head_ref, :base_ref], unique: true, name: "idx_prs_on_train_run_id_and_head_ref_and_base_ref"
  end
end
