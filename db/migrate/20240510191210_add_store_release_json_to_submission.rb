class AddStoreReleaseJsonToSubmission < ActiveRecord::Migration[7.0]
  def change
    add_column :store_submissions, :store_release, :jsonb
  end
end
