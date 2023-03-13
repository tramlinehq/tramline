module Displayable
  extend ActiveSupport::Concern

  class_methods do
    def display
      model_name.human
    end
  end

  included do
    delegate :display, to: self

    def display_attr(attr)
      self.class.human_attr_value(attr, public_send(attr))
    end
  end
end
