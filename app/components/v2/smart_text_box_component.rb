class V2::SmartTextBoxComponent < V2::BaseComponent
  ICON_STYLES = "text-secondary absolute end-3 top-3 -translate-y-1 translate-x-[0.1rem] "
  INPUT_STYLES = EnhancedFormHelper::AuthzForm::TEXT_FIELD_CLASSES + " text-secondary"
  ACTIONS_STYLES = "bg-main-50 border border-main-300 text-main rounded-r-lg focus:ring-primary-600 focus:border-primary-600 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500 ml-0.5"
  SIZES = %i[default compact].freeze

  def initialize(value, label: nil, clipboard: true, clipboard_tooltip: "Copy to clipboard", password: false, size: :default)
    raise ArgumentError, "size must be :default or :compact" unless SIZES.include?(size)

    @value = value
    @size = size
    @label = label
    @clipboard = clipboard
    @clipboard_tooltip = clipboard_tooltip
    @password = password
  end

  attr_reader :value, :clipboard_tooltip

  def id
    @id ||= SecureRandom.hex(6) + value
  end

  def actions_styles
    return "#{ACTIONS_STYLES} p-1.5" if compact?
    "#{ACTIONS_STYLES} p-2.5"
  end

  def icon_styles
    return "#{ICON_STYLES} top-3" if compact?
    "#{ICON_STYLES} top-5"
  end

  def input_styles
    return "#{INPUT_STYLES} !p-1.5 !text-xs" if compact?
    INPUT_STYLES
  end

  def compact?
    @size == :compact
  end

  def label?
    @label&.strip.present?
  end

  def type
    @password ? "password" : "text"
  end

  def data_controllers
    c = "clipboard"
    c += " password-visibility" if @password
    c
  end
end
