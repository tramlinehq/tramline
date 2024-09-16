class AddBitbucketWorkspaceToAppConfig < ActiveRecord::Migration[7.2]
  def change
    add_column :app_configs, :bitbucket_workspace, :string, null: true
  end
end
