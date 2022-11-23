module Displayable
  extend ActiveSupport::Concern

  class_methods do
    def display
      model_name.human
    end
  end

  included do
    delegate :display, to: self
  end
end
