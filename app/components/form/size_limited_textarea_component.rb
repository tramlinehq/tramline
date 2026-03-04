# frozen_string_literal: true

class Form::SizeLimitedTextareaComponent < ViewComponent::Base
  renders_one :info_icon, InfoIconComponent

  def initialize(form:, obj_method:, label_text:, max_length:, existing_value: nil, label_type: :default)
    @form = form
    @obj_method = obj_method
    @label_text = label_text
    @max_length = max_length
    @existing_value = existing_value
    @label_type = label_type
  end

  attr_reader :form, :obj_method, :label_text, :max_length, :existing_value, :label_type

  def textarea_options
    {
      placeholder: "Write #{label_text.downcase} here",
      value: existing_value,
      data: {
        controller: "textarea-autogrow",
        character_counter_target: "input",
        action: "input->character-counter#update"
      }
    }
  end

  def current_length
    existing_value&.length || 0
  end
end