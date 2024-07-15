module Linkable
  extend ActiveSupport::Concern

  class_methods do
    include Rails.application.routes.url_helpers

    def link_params(port: ENV["PORT_NUM"])
      if Rails.env.development?
        {
          host: ENV["HOST_NAME"], protocol: "https", port:
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
