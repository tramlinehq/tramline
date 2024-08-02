require "descope"

Rails.application.config.descope_client = Descope::Client.new(
  {
    project_id: ENV["DESCOPE_PROJECT_ID"],
    management_key: ENV["DESCOPE_MANAGEMENT_KEY"]
  }
)
