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

    def tunneled_link_params
      if Rails.env.development?
        {
          host: ENV["TUNNELED_HOST_NAME"], protocol: "https"
        }
      else
        link_params
      end
    end
  end

  included do
    include Rails.application.routes.url_helpers
    delegate :link_params, :tunneled_link_params, to: self
  end
end
