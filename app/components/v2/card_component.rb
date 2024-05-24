class V2::CardComponent < ViewComponent::Base
  renders_one :actions
  renders_one :empty_state, ->(**args) {
    empty_state_params = {type: :tiny}.merge(**args)
    V2::EmptyStateComponent.new(**empty_state_params)
  }

  SIZE = {
    xs: "max-h-80",
    base: "max-h-96",
    full: "max-h-full"
  }

  def initialize(title:, subtitle: nil, fold: false, separator: true, classes: nil, size: :full, emptiness: false, fixed_height: nil)
    @title = title
    @subtitle = subtitle
    @fold = fold
    @separator = separator
    @classes = classes
    @size = SIZE[size]
    @emptiness = emptiness
    @fixed_height = "h-#{fixed_height}" if fixed_height
  end

  attr_reader :title, :subtitle, :emptiness

  def card_params
    size_class = fold? ? "" : @size
    params = {class: "flex flex-col card-default #{y_gap} #{@classes} #{size_class} #{@fixed_height}"}
    params[:data] = fold_params if fold?
    params
  end

  def fold_params
    {controller: "fold", fold_expanded_value: "max-h-fit", fold_collapsed_value: @size}
  end

  def fold_target_params
    params = {}
    params[:data] = {fold_target: "foldable"} if fold?
    params[:class] = (fold? || base?) ? "overflow-y-auto " : ""
    params[:class] += "h-full" if fixed_height?
    params
  end

  def fold_button_params
    params = {class: "me-2"}
    params[:data] = {action: "click->fold#toggle"} if fold?
    params
  end

  def separator_style
    return "border-default-b pb-2" if separator?
    ""
  end

  def y_gap
    return "gap-y-3.5" if separator?
    "gap-y-5"
  end

  def fold? = @fold

  def separator? = @separator

  def full? = @size == SIZE[:full]

  def base? = @size == SIZE[:base]

  def fixed_height? = @fixed_height.present?
end
