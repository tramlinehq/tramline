class V2::ModalComponent < V2::BaseComponent
  BASE_OPTS = {html_options: {data: {action: "click->reveal#toggle"}}}.freeze
  SIZES = [:xsmall, :small, :medium, :large, :full].freeze
  SIZE_TO_WIDTH = {
    xxsmall: "max-w-xs",
    xsmall: "max-w-sm",
    small: "max-w-md",
    medium: "max-w-lg",
    large: "max-w-xl",
    full: "max-w-2xl",
    default: "max-w-xl"
  }.freeze

  renders_one :button, ->(**args) do
    args = args.merge(authz: @authz) # trickle down the auth setting to the button
    V2::ButtonComponent.new(**BASE_OPTS.deep_merge(**args))
  end
  renders_one :body

  def initialize(title:, size: :full, authz: true)
    @title = title
    @size = size
    @authz = authz
  end

  attr_reader :title

  def reveal_data_attrs
    if disabled?
      {}
    else
      {
        data: {
          controller: "reveal",
          reveal_away_value: "true",
          reveal_target_selector_value: "[data-modal-reveal]"
        }
      }
    end
  end

  def max_width
    SIZE_TO_WIDTH.fetch(@size, SIZE_TO_WIDTH[:default])
  end
end
