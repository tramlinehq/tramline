class AddIntegrableToSubmissionConfig < ActiveRecord::Migration[7.2]
  def change
    add_column :submission_configs, :integrable_id, :uuid, null: true
    add_column :submission_configs, :integrable_type, :string, null: true
  end
end
