module Vaultable
  extend ActiveSupport::Concern

  included do
    private

    def creds
      if Seed.not_demo_mode?
        Rails.application.credentials
      else
        OpenStruct.new(
          integrations: OpenStruct.new(
            github: OpenStruct.new(
              app_name: "demo-github-app",
              app_id: "1234567890" # This is just a dummy app id for demo_starter script
            )
          )
        )
      end
    end
  end
end
