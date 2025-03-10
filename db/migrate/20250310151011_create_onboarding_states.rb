class CreateOnboardingStates < ActiveRecord::Migration[7.2]
  def change
    create_table :onboarding_states do |t|
      t.references :app, null: false, foreign_key: true, type: :uuid
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end

    add_index :onboarding_states, :app_id, unique: true, if_not_exists: true
  end
end
