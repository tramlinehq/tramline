module CoreExtensions
  module IntercomRails
    module AutoInclude
      def self.csp_nonce_hook(controller)
        Base64.strict_encode64(controller.request.session.id.to_s)
      end
    end
  end
end
