module Vaultable
  extend ActiveSupport::Concern

  included do
    private

    # Override the credentials accessor with a safe fallback
    # This returns an empty object that handles method_missing
    def creds
      # Return empty hash or the safe credentials from application.rb
      Rails.application.credentials
    end
  end
end
