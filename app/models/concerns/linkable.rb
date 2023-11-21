module Linkable
  extend ActiveSupport::Concern

  class_methods do
    include Rails.application.routes.url_helpers

    def link_params
      if Rails.env.development?
        {
          host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"]
        }
      else
        {
          host: ENV["HOST_NAME"], protocol: "https"
        }
      end
    end
  end

  included do
    include Rails.application.routes.url_helpers
    delegate :link_params, to: self
  end
end
