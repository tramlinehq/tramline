# frozen_string_literal: true

class Form::RadioCardsComponent < ViewComponent::Base
  Option = Struct.new(:value, :label, keyword_init: true)
  BASE_CLASSES = "inline-flex items-center px-3 py-2 text-sm text-main border border-main-300 rounded-lg cursor-pointer hover:bg-main-50 dark:text-white dark:border-main-600 dark:hover:bg-main-700"
  CHECKED_CLASSES = "peer-checked:border-blue-600 peer-checked:text-blue-600 peer-checked:bg-blue-50 dark:peer-checked:border-blue-500 dark:peer-checked:text-blue-400 dark:peer-checked:bg-blue-900/20"

  def initialize(form:, field_name:, options:, selected_value: nil, description: nil, disabled: false)
    @form = form
    @field_name = field_name
    @options = options.map { |opt| opt.is_a?(Option) ? opt : Option.new(**opt) }
    @selected_value = selected_value
    @description = description
    @disabled = disabled
  end

  attr_reader :form, :field_name, :options, :selected_value, :description, :disabled

  def selected?(option)
    option.value.to_s == selected_value.to_s
  end

  def radio_card_classes
    "#{BASE_CLASSES} #{CHECKED_CLASSES}"
  end
end
