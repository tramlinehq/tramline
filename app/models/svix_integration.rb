# == Schema Information
#
# Table name: svix_integrations
#
#  id            :uuid             not null, primary key
#  status        :string           default("inactive"), indexed
#  svix_app_name :string
#  svix_app_uid  :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  svix_app_id   :string           indexed
#  train_id      :uuid             not null, indexed
#
class SvixIntegration < ApplicationRecord
  has_paper_trail
  include Loggable

  belongs_to :train

  validates :svix_app_id, uniqueness: true, allow_nil: true
  validates :status, presence: true

  enum :status, {active: "active", inactive: "inactive"}

  def display_name = "Svix Webhook"

  def metadata = svix_app_id

  def connection_data
    return if unavailable?
    "Svix App ID: #{svix_app_id}"
  end

  def unavailable?
    inactive? || svix_app_id.blank?
  end

  def available?
    !unavailable?
  end

  def portal_access_link
    svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])

    begin
      portal_access =
        svix_client.authentication.app_portal_access(svix_app_id, {expires_at: 6.hours.from_now})
      portal_access.url
    rescue Svix::ApiError
      nil
    end
  end

  def create_app!
    with_retry do
      svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
      app_name = new_app_name
      app_uid = new_app_uid

      application_in = Svix::ApplicationIn.new(name: app_name, uid: app_uid)
      response = svix_client.application.create(application_in)

      update!(svix_app_id: response.id, svix_app_uid: app_uid, svix_app_name: app_name, status: :active)
      response
    end
  end

  def delete_app!(app_id: svix_app_id)
    return if unavailable?

    with_retry do
      svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
      svix_client.application.delete(app_id)
      update!(svix_app_id: nil, svix_app_uid: nil, svix_app_name: nil, status: :inactive)
    end
  end

  def send_message(payload)
    return if unavailable?

    with_retry do
      svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
      message_in = Svix::MessageIn.new(event_type: payload[:event_type], payload: payload)
      response = svix_client.message.create(svix_app_id, message_in)
      JSON.parse(response.to_json)
    end
  end

  private

  def new_app_name
    "#{train.organization.name} • #{train.app.name} • #{train.name}"
  end

  def new_app_uid
    "tramline-#{train.id}--#{SecureRandom.uuid}"
  end

  MAX_RETRY_ATTEMPTS = 3
  WebhookApiError = Class.new(StandardError)

  def with_retry
    attempt = 0

    begin
      yield
    rescue Svix::ApiError, StandardError => error
      if attempt < MAX_RETRY_ATTEMPTS && server_error?(error)
        elog("Svix API error for train #{train.id}, retrying attempt #{attempt + 1}", level: :warn)
        sleep 0.1 * (attempt + 1)
        attempt += 1
        retry
      else
        elog(generic_error_message(error), level: :error)
        raise WebhookApiError, error
      end
    rescue => error
      elog(generic_error_message(error), level: :error)
      raise
    end
  end

  def server_error?(error)
    error.code == 500
  end

  def generic_error_message(error)
    "Failed to create Svix app for train #{train.id}: #{error.message}"
  end
end
