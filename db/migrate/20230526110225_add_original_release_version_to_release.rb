class AddOriginalReleaseVersionToRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :train_runs, :original_release_version, :string
  end
end
