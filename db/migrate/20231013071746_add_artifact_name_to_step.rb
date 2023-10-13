class AddArtifactNameToStep < ActiveRecord::Migration[7.0]
  def change
    add_column :steps, :build_artifact_name_pattern, :string
  end
end
