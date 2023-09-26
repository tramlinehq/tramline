class AddCompactBuildNotesFlagToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :compact_build_notes, :boolean, default: false
  end
end
