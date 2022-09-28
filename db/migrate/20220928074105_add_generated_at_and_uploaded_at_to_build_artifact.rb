class AddGeneratedAtAndUploadedAtToBuildArtifact < ActiveRecord::Migration[7.0]
  def change
    add_column :build_artifacts, :generated_at, :timestamp, null: true
    add_column :build_artifacts, :uploaded_at, :timestamp, null: true
  end
end
