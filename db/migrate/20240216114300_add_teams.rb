class AddTeams < ActiveRecord::Migration[7.0]
  def change
    create_table :teams, id: :uuid do |t|
      t.belongs_to :organization, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :color, null: false

      t.timestamps
    end

    add_column :memberships, :team_id, :uuid, null: true
  end
end
