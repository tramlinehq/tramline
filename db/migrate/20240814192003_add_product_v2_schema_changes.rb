class AddProductV2SchemaChanges < ActiveRecord::Migration[7.0]
  def change
    create_table :store_rollouts, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :store_submission, null: true, index: true, foreign_key: true, type: :uuid

      t.string :type, null: false
      t.string :status, null: false
      t.datetime :completed_at
      t.integer :current_stage, limit: 2
      t.decimal :config, precision: 8, scale: 5, default: [], array: true, null: false
      t.boolean :is_staged_rollout, default: false

      t.timestamps
    end

    create_table :production_releases, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :build, null: false, foreign_key: true, type: :uuid
      t.references :previous, foreign_key: {to_table: :production_releases}, index: true, type: :uuid
      t.jsonb :config, null: false, default: {}
      t.string :status, null: false, default: "inflight"
      t.timestamps
    end

    add_index :production_releases, [:release_platform_run_id, :status], unique: true, name: "index_unique_inflight_production_release", where: "status = 'inflight'"
    add_index :production_releases, [:release_platform_run_id, :status], unique: true, name: "index_unique_active_production_release", where: "status = 'active'"
    add_index :production_releases, [:release_platform_run_id, :status], unique: true, name: "index_unique_finished_production_release", where: "status = 'finished'"

    create_table :pre_prod_releases, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :commit, null: false, index: true, foreign_key: true, type: :uuid
      t.references :previous, foreign_key: {to_table: :pre_prod_releases}, index: true, type: :uuid
      t.references :parent_internal_release, foreign_key: {to_table: :pre_prod_releases}, type: :uuid, index: true
      t.string :type, null: false
      t.string :status, null: false, default: "created"
      t.jsonb :config, null: false, default: {}
      t.text :tester_notes
      t.timestamps
    end

    create_table :workflow_runs, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :commit, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :pre_prod_release, null: false, index: true, foreign_key: true, type: :uuid
      t.string :status, null: false
      t.string :kind, null: false, default: "release_candidate"
      t.jsonb :workflow_config
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
        t.bigint :size_in_bytes
        t.integer :sequence_number, null: false, default: 0, limit: 2, index: true
        t.string :slack_file_id
      end

      change_table :store_submissions do |t|
        t.references :parent_release, polymorphic: true, null: true, index: true, type: :uuid # TODO: add the not-null constraint back in a later migration
        t.jsonb :config, null: true # TODO: add the not-null constraint back in a later migration
        t.integer :sequence_number, null: false, default: 0, limit: 2, index: true
      end

      change_column_null :store_submissions, :build_id, false
    end

    change_column_null :build_artifacts, :step_run_id, true
  end
end
