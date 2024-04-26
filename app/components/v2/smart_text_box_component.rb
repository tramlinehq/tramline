class V2::SmartTextBoxComponent < V2::BaseComponent
  ICON_STYLES = "text-secondary absolute end-3 top-3 -translate-y-1 translate-x-[0.1rem] "
  INPUT_STYLES = EnhancedFormHelper::AuthzForm::TEXT_FIELD_CLASSES + " text-secondary"
  SIZES = %i[default compact].freeze

  def initialize(value, clipboard: true, clipboard_tooltip: "Copy to clipboard", password: false, size: :default)
    raise ArgumentError, "size must be :default or :compact" unless SIZES.include?(size)

    @value = value
    @size = size
    @clipboard = clipboard
    @clipboard_tooltip = clipboard_tooltip
    @password = password
  end

  attr_reader :value, :clipboard_tooltip

  def id
    @id ||= SecureRandom.hex(6) + value
  end

  def icon_styles
    return "#{ICON_STYLES} top-3" if compact?
    "#{ICON_STYLES} top-5" if default?
  end

  def input_styles
    return "#{INPUT_STYLES} !p-1.5 !text-xs" if compact?
    INPUT_STYLES
  end

  def compact?
    @size == :compact
  end

  def default?
    @size == :default
  end
end
