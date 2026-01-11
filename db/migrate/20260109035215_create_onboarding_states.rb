class CreateOnboardingStates < ActiveRecord::Migration[7.2]
  def change
    create_table :onboarding_states, id: :uuid do |t|
      t.references :app, null: false, foreign_key: true, type: :uuid
      t.string :field_1
      t.string :field_2
      t.string :field_3

      t.timestamps
    end
  end
end
