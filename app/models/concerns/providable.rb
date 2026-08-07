module Providable
  extend ActiveSupport::Concern

  included do
    has_one :integration, as: :providable, dependent: :destroy
  end

  def rotatable?
    false
  end
end
