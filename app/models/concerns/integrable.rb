module Integrable
  extend ActiveSupport::Concern

  included do
    has_many :integrations, as: :integrable, dependent: :destroy
  end
end
