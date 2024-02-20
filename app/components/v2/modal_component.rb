class V2::ModalComponent < V2::BaseComponent
  BASE_OPTS = {html_options: {data: {action: "click->modal#open"}}}.freeze
  SIZE_TO_WIDTH = {
    xxs: "max-w-xs",
    xs: "max-w-sm",
    sm: "max-w-md",
    md: "max-w-lg",
    lg: "max-w-xl",
    default: "max-w-2xl",
  }.freeze

  renders_one :button, ->(**args) do
    args = args.merge(authz: @authz) # trickle down the auth setting to the button
    V2::ButtonComponent.new(**BASE_OPTS.deep_merge(**args))
  end

  renders_one :body

  def initialize(title:, subtitle: nil, size: :default, authz: true, dismissable: true)
    raise ArgumentError, "Invalid size" unless SIZE_TO_WIDTH.key?(size.to_sym)

    @title = title
    @subtitle = subtitle
    @size = size
    @authz = authz
    @dismissable = dismissable
  end

  attr_reader :title, :subtitle, :dismissable

  def reveal_data_attrs
    if disabled?
      {}
    else
      { data: { controller: "modal", modal_dismissable_value: dismissable } }
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
end
