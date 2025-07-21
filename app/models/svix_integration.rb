# == Schema Information
#
# Table name: svix_integrations
#
#  id         :uuid             not null, primary key
#  app_name   :string
#  status     :string           default("active"), indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :string           indexed
#
class SvixIntegration < ApplicationRecord
  has_paper_trail
  include Providable
  include Displayable

  validates :app_id, uniqueness: true, allow_nil: true
  validates :status, presence: true

  enum :status, {active: "active", inactive: "inactive"}

  delegate :app, to: :integration
  
  def train
    # SvixIntegration is linked to trains through the background job
    # For now, we'll find the train that triggered this integration creation
    app.trains.first if app
  end

  def install_path
    nil
  end

  def complete_access
    true
  end

  def to_s
    "svix"
  end

  def creatable?
    false
  end

  def connectable?
    true
  end

  def store?
    false
  end

  def project_link
    nil
  end

  def further_setup?
    false
  end

  def public_icon_img
    "https://storage.googleapis.com/tramline-public-assets/svix_small.png"
  end

  def display
    "Svix Webhooks"
  end

  def metadata
    app_id
  end

  def connection_data
    return unless app_id.present?
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
    return unless app_id.present?

    svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
    endpoint_in = Svix::EndpointIn.new(
      url: url,
      eventTypes: ["release.started", "release.ended", "rc.finished"]
    )
    
    svix_client.endpoint.create(app_id, endpoint_in)
  end
end
