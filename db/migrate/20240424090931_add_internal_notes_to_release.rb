class AddInternalNotesToRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :releases, :internal_notes, :jsonb, null: true, default: {}
  end
end
