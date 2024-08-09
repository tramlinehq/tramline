class RenameSubmissionConfigToConfig < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      rename_column :store_submissions, :submission_config, :config
    end
  end
end
