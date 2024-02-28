class V2::AlertComponent < ViewComponent::Base
  COLORS = {
    notice: "text-blue-800 bg-blue-50 dark:bg-gray-800 dark:text-blue-400",
    error: "text-red-800 bg-red-50 dark:bg-gray-800 dark:text-red-400",
    alert: "text-red-800 bg-red-50 dark:bg-gray-800 dark:text-red-400",
    success: "text-green-800 bg-green-50 dark:bg-gray-800 dark:text-green-400"
  }

  STYLES = {
    notice: "border-t-4 border-blue-300 dark:border-blue-800 " + COLORS[:notice],
    error: "border-t-4 border-red-300 dark:border-red-800 " + COLORS[:error],
    alert: "border-t-4 border-red-300 dark:border-red-800 " + COLORS[:alert],
    success: "border-t-4 border-green-300 dark:border-green-800 " + COLORS[:success]
  }

  SIZES = {
    base: "w-full",
    sm: "min-w-60",
    md: "min-w-80",
    lg: "w-1/2",
    xl: "w-3/4"
  }

  ACTION_BUTTON_STYLES = "flex items-center text-center text-blue-800 bg-transparent border border-blue-800 hover:bg-blue-900 hover:text-white focus:ring-4 focus:outline-none focus:ring-blue-200 font-medium rounded-lg text-xs px-3 py-1.5 dark:hover:bg-blue-600 dark:border-blue-600 dark:text-blue-400 dark:hover:text-white dark:focus:ring-blue-800"

  KINDS = [:alert, :more_info]

  def initialize(kind: :alert, type: :notice, title: "Alert", size: :base, dismissible: true, info: nil)
    raise ArgumentError, "Invalid type" unless COLORS.key?(type.to_sym)
    raise ArgumentError, "Invalid size" unless SIZES.key?(size.to_sym)
    raise ArgumentError, "Invalid kind" unless KINDS.include?(kind.to_sym)
    raise ArgumentError, "Info is supplied only with more_info type" if kind == :alert && info.present?

    @type = type.to_sym
    @title = title
    @size = size.to_sym
    @kind = kind.to_sym
    @info = info
    @dismissible = dismissible
  end

  attr_reader :title, :dismissible, :info

  def size
    SIZES[@size]
  end

  def style
    STYLES[@type]
  end

  def colors
    COLORS[@type]
  end

  def alert?
    @kind == :alert
  end

  def more_info?
    @kind == :more_info
  end

  def info?
    @info.present? && @info[:label].present? && @info[:link].present?
  end
end
