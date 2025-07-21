# == Schema Information
#
# Table name: svix_integrations
#
#  id         :bigint           not null, primary key
#  app_name   :string
#  status     :string           default("active"), indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :string           indexed
#  train_id   :uuid             not null, indexed
#
class SvixIntegration < ApplicationRecord
  has_paper_trail

  belongs_to :train

  validates :app_id, uniqueness: true, allow_nil: true
  validates :status, presence: true
  validates :train_id, presence: true

  enum :status, {active: "active", inactive: "inactive"}

  def display_name
    "Svix Webhooks"
  end

  def metadata
    app_id
  end

  def connection_data
    return if app_id.blank?
    "Svix App ID: #{app_id}"
  end

  def create_svix_app!
    return if app_id.present?

    svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
    app_name = "#{train.app.name} - #{train.name}"

    application_in = Svix::ApplicationIn.new(
      name: app_name,
      uid: "tramline-#{train.id}"
    )

    response = svix_client.application.create(application_in)

    update!(
      app_id: response.id,
      app_name: app_name,
      status: :active
    )

    response
  end

  def create_endpoint(url)
    return if app_id.blank?

    svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
    endpoint_in = Svix::EndpointIn.new(
      url: url,
      eventTypes: ["release.started", "release.ended", "rc.finished"]
    )

    svix_client.endpoint.create(app_id, endpoint_in)
  end

  def send_message(payload)
    return if app_id.blank?

    svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
    message_in = Svix::MessageIn.new(
      event_type: payload[:event_type],
      payload: payload
    )

    svix_client.message.create(app_id, message_in)
  end
end
