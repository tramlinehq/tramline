# == Schema Information
#
# Table name: svix_integrations
#
#  id            :uuid             not null, primary key
#  status        :string           default("inactive"), indexed
#  svix_app_name :string
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

  def create_app!
    svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
    application_in = Svix::ApplicationIn.new(name: new_app_name, uid: new_app_uid)

    response = svix_client.application.create(application_in)
    update!(svix_app_id: response.id, svix_app_name: new_app_name, status: :active)

    response
  rescue HTTP::Error, Faraday::Error, StandardError => error
    elog("Failed to create Svix app for train #{train.id}: #{error.message}", level: :warn)
    raise error
  end

  def send_message(payload)
    return if unavailable?

    begin
      svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
      message_in = Svix::MessageIn.new(event_type: payload[:event_type], payload: payload)
      response = svix_client.message.create(svix_app_id, message_in)
      JSON.parse(response)
    rescue HTTP::Error, Faraday::Error, StandardError => error
      elog("Failed to send Svix message for app #{svix_app_id}: #{error.message}", level: :warn)
      raise error
    end
  end

  private

  def new_app_name
    "#{train.organization.name} • #{train.app.name} • #{train.name}"
  end

  def new_app_uid
    "tramline-#{train.id}"
  end
end
