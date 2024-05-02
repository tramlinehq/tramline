class V2::CardComponent < ViewComponent::Base
  renders_one :actions
  SIZE = {
    xs: "max-h-80",
    sm: "max-h-96",
    full: "max-h-full"
  }

  def initialize(title:, fold: false, separator: true, classes: nil, size: :sm)
    @title = title
    @fold = fold
    @separator = separator
    @classes = classes
    @size = SIZE[size]
  end

  attr_reader :title

  def card_params
    params = {class: "flex flex-col border-default box-padding gap-y-2 #{@classes} #{@size}"}
    params[:data] = fold_params if fold?
    params
  end

  def fold_params
    {controller: "fold", fold_expanded_value: "max-h-fit", fold_collapsed_value: @size}
  end

  def fold_target_params
    params = {}
    params[:data] = {fold_target: "foldable"} if fold?
    params[:class] = "overflow-y-scroll" if fold? || !full?
    params
  end

  def fold_button_params
    params = {class: "me-2"}
    params[:data] =  {action: "click->fold#toggle"} if fold?
    params
  end

  def fold? = @fold

  def separator? = @separator

  def full? = @size == SIZE[:full]
end

