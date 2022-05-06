module Vaultable
  extend ActiveSupport::Concern

  included do
    private

    def creds
      Rails.application.credentials
    end
  end
end
