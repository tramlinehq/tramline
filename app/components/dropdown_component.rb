class DropdownComponent < ViewComponent::Base
  renders_one :menu, "Dropdown::Menu"
  renders_one :icon, ->(classes:, &block) { content_tag :span, class: classes, &block }
  renders_one :main_text, ->(classes:, &block) { content_tag :span, class: classes, &block }
end
