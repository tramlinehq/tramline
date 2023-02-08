class Dropdown::Menu < ViewComponent::Base
  renders_many :items, "ItemComponent"

  class ItemComponent < ViewComponent::Base
    def initialize(selected: false)
      @selected = selected
    end

    attr_reader :selected

    def call
      content_tag(:span, content)
    end
  end
end
