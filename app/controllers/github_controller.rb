class GithubController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  delegate :transaction, to: ActiveRecord::Base

  def events
    head :unprocessable_entity and return if train.blank?
    head :unprocessable_entity and return if train.inactive?
    head :accepted and return if train.current_run.blank?
    head :accepted and return if train.current_run.last_running_step.blank?

    transaction do
      current_run = train.current_run
      current_run.last_running_step.wrap_up_run!

      Automatons::Notify.dispatch!(
        message: "Notified via github webhook: Workflow finished for #{current_run.code_name}!",
        integration: notification_integration
      )
    end

    head :ok
  end

  def notification_integration
    train.integrations.notification.first
  end

  def train
    Releases::Train.find_by(id: params[:train_id])
  end
end
