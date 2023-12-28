class V2::AlertComponent < ViewComponent::Base
  COLORS = {
    blue: "text-blue-800 bg-blue-50 dark:bg-gray-800 dark:text-blue-400",
    red: "text-red-800 bg-red-50 dark:bg-gray-800 dark:text-red-400",
    green: "text-green-800 bg-green-50 dark:bg-gray-800 dark:text-green-400",
    yellow: "text-yellow-800 bg-yellow-50 dark:bg-gray-800 dark:text-yellow-300",
    gray: "text-gray-800 bg-gray-50 dark:bg-gray-800 dark:text-gray-300"
  }

  STYLES = {
    blue: "border-t-4 border-blue-300 dark:border-blue-800 " + COLORS[:blue],
    red: "border-t-4 border-red-300 dark:border-red-800 " + COLORS[:red],
    green: "border-t-4 border-green-300 dark:border-green-800 " + COLORS[:green],
    yellow: "border-t-4 border-yellow-300 dark:border-yellow-800 " + COLORS[:yellow],
    gray: "border-t-4 border-gray-300 dark:border-gray-600" + COLORS[:gray]
  }

  SIZES = {
    base: "w-full",
    sm: "min-w-60",
    md: "min-w-80",
    lg: "w-1/2",
    xl: "w-3/4",
  }

  def initialize(type: :blue, title: "Alert", size: :base)
    @type = type.to_sym
    @title = title
    @size = size.to_sym
  end

  attr_reader :title

  def size
    SIZES[@size]
  end

  def style
    STYLES[@type]
  end

  def colors
    COLORS[@type]
  end
end
