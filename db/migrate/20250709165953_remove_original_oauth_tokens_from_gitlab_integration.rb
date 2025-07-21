class RemoveOriginalOauthTokensFromGitlabIntegration < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :gitlab_integrations, :original_oauth_access_token, :string
      remove_column :gitlab_integrations, :original_oauth_refresh_token, :string
    end
  end
end
