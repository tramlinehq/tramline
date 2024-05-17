class V2::AlertComponent < V2::BaseComponent
  COLORS = {
    notice: "text-blue-900 bg-blue-50 dark:bg-main-800 dark:text-blue-400",
    error: "text-red-800 bg-red-50 dark:bg-main-800 dark:text-red-400",
    alert: "text-red-800 bg-red-50 dark:bg-main-800 dark:text-red-400",
    success: "text-green-800 bg-green-50 dark:bg-main-800 dark:text-green-400",
    info: "text-main-800 bg-main-50 dark:bg-main-800 dark:text-main-400"
  }

  STYLES = {
    notice: "border border-blue-300 dark:border-blue-800 " + COLORS[:notice],
    error: "border border-red-300 dark:border-red-800 " + COLORS[:error],
    alert: "border border-red-300 dark:border-red-800 " + COLORS[:alert],
    success: "border border-green-300 dark:border-green-800 " + COLORS[:success],
    info: "border border-main-300 dark:border-main-800 " + COLORS[:info]
  }

  SIZES = {
    base: "w-full",
    sm: "min-w-60",
    md: "min-w-80",
    lg: "w-1/2",
    xl: "w-3/4"
  }

  ACTION_BUTTON_STYLES = "flex items-center text-center text-blue-800 bg-transparent border border-blue-800 hover:bg-blue-900 hover:text-white focus:ring-4 focus:outline-none focus:ring-blue-200 font-medium rounded-lg text-xs px-3 py-1.5 dark:hover:bg-blue-600 dark:border-blue-600 dark:text-blue-400 dark:hover:text-white dark:focus:ring-blue-800"

  KINDS = [:alert, :banner]

  def initialize(kind: :alert, type: :notice, title: "Alert", size: :base, dismissible: true, info: nil, full_screen: nil)
    full_screen = full_screen.nil? ? (kind == :banner) : full_screen
    raise ArgumentError, "Invalid type" unless COLORS.key?(type.to_sym)
    raise ArgumentError, "Invalid size" unless SIZES.key?(size.to_sym)
    raise ArgumentError, "Invalid kind" unless KINDS.include?(kind.to_sym)
    raise ArgumentError, "Info is supplied only with banner type" if kind == :alert && info.present?
    raise ArgumentError, "Only banners can be fullscreen" if full_screen && kind != :banner

    @type = type.to_sym
    @title = title
    @size = size.to_sym
    @kind = kind.to_sym
    @info = info
    @dismissible = dismissible
    @full_screen = full_screen
  end

  attr_reader :title, :dismissible, :info, :full_screen, :type

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

  def banner?
    @kind == :banner
  end

  def info?
    @info.present? && @info[:label].present? && @info[:link].present?
  end

  def border_style
    return if full_screen
    "rounded-lg"
  end
end
