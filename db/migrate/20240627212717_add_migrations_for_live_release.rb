class AddMigrationsForLiveRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :store_rollouts do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :store_submission, null: true, index: true, foreign_key: true, type: :uuid

      t.string :type, null: false
      t.string :status, null: false
      t.datetime :completed_at
      t.integer :current_stage, limit: 2
      t.decimal :config, precision: 8, scale: 5, default: [], array: true, null: false

      t.timestamps
    end

    create_table :production_releases do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :build, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    create_table :pre_prod_releases do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.string :type, null: false
      t.string :status, null: false
      t.timestamps
    end

    create_table :workflow_runs, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :commit, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :pre_prod_release, null: false, index: true, foreign_key: true
      t.string :status, null: false
      t.jsonb :workflow_config
      t.string :build_number
      t.string :external_id
      t.string :external_url
      t.string :external_number
      t.string :artifacts_url
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    safety_assured do
      change_table :builds, bulk: true do |t|
        t.belongs_to :workflow_run, type: :uuid, null: true, index: true, foreign_key: true
        t.string :external_id
        t.string :external_name
        t.integer :size_in_bytes
        t.integer :sequence_number, null: false, default: 0, limit: 2, index: true
        t.string :slack_file_id
      end

      change_table :store_submissions do |t|
        t.references :parent_release, polymorphic: true, null: false, index: true
        t.jsonb :submission_config, null: true
        t.integer :sequence_number, null: false, default: 0, limit: 2, index: true
      end

      change_column_null :store_submissions, :build_id, false
    end
  end
end
