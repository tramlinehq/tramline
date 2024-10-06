class CreatePlatformConfigAndAssociates < ActiveRecord::Migration[7.2]
  def change
    create_table :release_platform_configs do |t|
      t.belongs_to :release_platform, foreign_key: true, index: true, type: :uuid
      t.timestamps
    end

    create_table :workflow_configs do |t|
      t.references :release_platform_config, foreign_key: { to_table: :release_platform_configs }, index: true
      t.string :kind
      t.string :name
      t.string :identifier
      t.string :artifact_name_pattern
      t.timestamps
    end

    create_table :release_step_configs do |t|
      t.references :release_platform_config, foreign_key: { to_table: :release_platform_configs }, index: true
      t.string :kind
      t.boolean :auto_promote, default: false
      t.timestamps
    end

    create_table :submission_configs do |t|
      t.references :release_step_config, foreign_key: { to_table: :release_step_configs }, index: true
      t.integer :number, index: true
      t.string :submission_type
      t.decimal :rollout_stages, array: true, precision: 8, scale: 5, default: []
      t.boolean :rollout_enabled, default: false
      t.boolean :auto_promote, default: false
      t.timestamps
    end

    add_index :submission_configs, [:release_step_config_id, :number], unique: true

    create_table :submission_external_configs do |t|
      t.references :submission_config, foreign_key: { to_table: :submission_configs }, index: true
      t.string :identifier
      t.string :name
      t.boolean :internal, default: false
      t.timestamps
    end
  end
end
