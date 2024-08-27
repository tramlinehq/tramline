class V2::ModalComponent < V2::BaseComponent
  SIZE_TO_WIDTH = {
    xxs: "max-w-xs",
    xs: "max-w-sm",
    sm: "max-w-md",
    md: "max-w-lg",
    lg: "max-w-xl",
    xxl: "max-w-3xl",
    xl_3: "max-w-4xl",
    xl_4: "max-w-5xl",
    default: "max-w-2xl"
  }.freeze

  renders_one :button, ->(**args) do
    args = args.merge(authz: @authz) # trickle down the auth setting to the button
    V2::ButtonComponent.new(**button_attrs.deep_merge(**args))
  end

  renders_one :body

  def initialize(title:, type: :dialog, subtitle: nil, size: :default, authz: true, dismissable: true)
    raise ArgumentError, "Invalid size" unless SIZE_TO_WIDTH.key?(size.to_sym)

    @title = title
    @type = type
    @subtitle = subtitle
    @size = size
    @authz = authz
    @dismissable = dismissable
  end

  attr_reader :title, :subtitle, :dismissable

  def reveal_data_attrs
    if disabled?
      {}
    elsif dialog?
      {class: "inline-flex items-center", data: {controller: "dialog", dialog_dismissable_value: dismissable}}
    elsif drawer?
      {class: "inline-flex items-center", data: {controller: "reveal", reveal_away_value: dismissable, reveal_target_selector_value: "[data-drawer-reveal]"}}
    end
  end

  def button_attrs
    if dialog?
      {html_options: {data: {action: "click->dialog#open"}}}
    elsif drawer?
      {html_options: {data: {action: "click->reveal#show"}}}
    end
  end

  def max_width
    SIZE_TO_WIDTH.fetch(@size, SIZE_TO_WIDTH[:default])
  end

  def default_separator
    if subtitle.blank?
      "border-default-b py-2"
    else
      ""
    end
  end

  def dialog?
    @type == :dialog
  end

  def drawer?
    @type == :drawer
  end
end
