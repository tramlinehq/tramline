class GithubController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  delegate :transaction, to: ActiveRecord::Base
  delegate :current_run, to: :train

  def providable_params
    super.merge({
      installation_id: installation_id
    })
  end

  def events
    head :accepted and return unless successful?
    head :unprocessable_entity and return if train.blank?
    head :unprocessable_entity and return if train.inactive?
    head :accepted and return if train.current_run.blank?
    head :accepted and return if train.current_run.last_running_step.blank?

    release_branch = train.current_run.release_branch
    code_name = train.current_run.code_name
    build_number = train.app.build_number
    version_number = train.version_current

    transaction do
      text_block =
        Notifiers::Slack::BuildFinished.render_json(
          artifact_link: artifacts_url,
          code_name: code_name,
          branch_name: release_branch,
          build_number: build_number,
          version_number: version_number
        )

      current_run.last_running_step.wrap_up_run!

      Automatons::Notify.dispatch!(
        train: train,
        message: "Your release workflow completed!",
        text_block: text_block
      )
    end

    head :ok
  end

  private

  def train
    Releases::Train.find_by(id: params[:train_id])
  end

  def successful?
    payload_status == "completed" && payload_conclusion == "success"
  end

  def payload_status
    params[:workflow_run][:status]
  end

  def payload_conclusion
    params[:workflow_run][:conclusion]
  end

  def artifacts_url
    params[:workflow_run][:artifacts_url]
  end
end
