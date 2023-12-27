class V2::AlertComponent < ViewComponent::Base
  STYLES = {
    blue: "text-blue-800 border-t-4 border-blue-300 bg-blue-50 dark:bg-gray-800 dark:text-blue-400 dark:border-blue-800",
    red: "text-red-800 border-t-4 border-red-300 bg-red-50 dark:bg-gray-800 dark:text-red-400 dark:border-red-800",
    green: "text-green-800 border-t-4 border-green-300 bg-green-50 dark:bg-gray-800 dark:text-green-400 dark:border-green-800",
    yellow: "text-yellow-800 border-t-4 border-yellow-300 bg-yellow-50 dark:bg-gray-800 dark:text-yellow-300 dark:border-yellow-800",
    gray: "text-gray-800 border-t-4 border-gray-300 bg-gray-50 dark:bg-gray-800 dark:text-gray-300 dark:border-gray-600"
  }

  SIZES = {
    base: "inline-flex w-full",
    sm: "inline-flex min-w-60",
    md: "inline-flex min-w-80",
    lg: "inline-flex w-1/2",
    xl: "inline-flex w-3/4",
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
end
