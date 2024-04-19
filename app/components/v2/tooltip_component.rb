class V2::TooltipComponent < V2::BaseComponent
  TOOLTIP_CLASSES = "absolute z-30 px-3 py-2 text-sm font-medium text-white bg-main-900 rounded-lg shadow-sm tooltip dark:bg-main-700"
  DETAILED_TOOLTIP_CLASSES = "absolute z-30 text-sm font-normal text-secondary bg-white border-default p-3 rounded-lg shadow-sm w-fit max-w-xs dark:bg-main-800 dark:border-main-600 dark:text-secondary-50"
  InvalidType = Class.new(ArgumentError)

  renders_one :body
  renders_one :detailed_text

  ALLOWED_TYPES = [:simple, :detailed]

  def initialize(text, placement: "bottom", type: :simple, cursor: true)
    raise InvalidType unless type.in?(ALLOWED_TYPES)

    @text = text
    @placement = placement
    @type = type
    @cursor = cursor
  end

  attr_reader :text, :placement, :type, :cursor

  def simple?
    type == :simple
  end

  def detailed?
    type == :detailed
  end

  def offset
    return [0, 8] if simple?
    [0, 6]
  end
end
