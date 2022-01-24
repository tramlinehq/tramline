class GithubController < ApplicationController
  require "string_utils"
  using StringUtils

  GITHUB_CLIENT_ID = "Iv1.c541cb029c8e6403"
  GITHUB_CLIENT_SECRET = "fff4a9a70c01133df7ccab05b32c7b3ec96ef541"

  def callback
    return unless valid_state?
    @integration = state_app.integrations.new(integration_params)

    respond_to do |format|
      if @integration.save
        notice = "Integration was successfully created."
        format.html { redirect_to accounts_organization_app_path(current_organization, state_app), notice: }
        format.json { render :show, status: :created, location: state_app }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: state_app.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def state
    @state ||= JSON.parse(params[:state].decrypt).with_indifferent_access
  end

  def installation_id
    params[:installation_id]
  end

  def valid_state?
    state_user.present? && state_organization.present? && state_app.present?
  end

  def integration_params
    {
      installation_id: installation_id,
      category: state_integration_category,
      provider: state_integration_provider
    }
  end

  def state_user
    @state_user ||= Accounts::User.find(state[:user_id])
  end

  def state_organization
    @state_organization ||= @state_user.organizations.find(state[:organization_id])
  end

  def state_app
    @state_app = @state_organization.apps.find(state[:app_id])
  end

  def state_integration_category
    state[:integration_category]
  end

  def state_integration_provider
    state[:integration_provider]
  end
end
