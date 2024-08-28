class V2::AlertComponent < V2::BaseComponent
  COLORS = {
    notice: "text-blue-900 bg-blue-50 dark:bg-main-800 dark:text-blue-400",
    error: "text-red-800 bg-red-50 dark:bg-main-800 dark:text-red-400",
    alert: "text-red-800 bg-red-50 dark:bg-main-800 dark:text-red-400",
    success: "text-green-800 bg-green-50 dark:bg-main-800 dark:text-green-400",
    info: "text-main-800 bg-main-50 dark:bg-main-800 dark:text-main-400",
    announce: "text-amber-800 bg-amber-50 dark:bg-amber-800 dark:text-amber-400"
  }

  STYLES = {
    notice: "border border-blue-300 dark:border-blue-800 " + COLORS[:notice],
    error: "border border-red-300 dark:border-red-800 " + COLORS[:error],
    alert: "border border-red-300 dark:border-red-800 " + COLORS[:alert],
    success: "border border-green-300 dark:border-green-800 " + COLORS[:success],
    info: "border border-main-300 dark:border-main-800 " + COLORS[:info],
    announce: "border border-amber-300 dark:border-amber-800 " + COLORS[:announce]
  }

  ACTION_BUTTON_STYLES = "flex items-center text-center text-blue-800 bg-transparent border border-blue-800 hover:bg-blue-900 hover:text-white focus:ring-4 focus:outline-none focus:ring-blue-200 font-medium rounded-lg text-xs px-3 py-1.5 dark:hover:bg-blue-600 dark:border-blue-600 dark:text-blue-400 dark:hover:text-white dark:focus:ring-blue-800"

  KINDS = [:alert, :banner, :announcement]

  renders_one :banner_action, V2::ButtonComponent
  renders_many :announcement_modals, V2::ModalComponent
  renders_many :announcement_buttons, V2::ButtonComponent

  def initialize(kind: :alert, type: :notice, title: "Alert", dismissible: false, info: nil, full_screen: true)
    raise ArgumentError, "Invalid type" unless COLORS.key?(type.to_sym)
    raise ArgumentError, "Invalid kind" unless KINDS.include?(kind.to_sym)
    raise ArgumentError, "Info is supplied only for banners" if kind != :banner && info.present?
    raise ArgumentError, "Announcements are not dismissible" if dismissible && kind == :announcement

    @type = type.to_sym
    @title = title
    @kind = kind.to_sym
    @info = info
    @dismissible = dismissible
    @full_screen = full_screen

    if banner?
      @type = :notice
      @size = :base
    end

    if announcement?
      @type = :announce
      @full_screen = false
    end
  end

  attr_reader :title, :dismissible, :info, :full_screen, :type

  def style
    STYLES[@type]
  end

  def colors
    COLORS[@type]
  end

  def padding
    return "p-4" if announcement?
    return "p-5" if banner?
    "px-4 py-2.5"
  end

  def alert?
    @kind == :alert
  end

  def banner?
    @kind == :banner
  end

  def announcement?
    @kind == :announcement
  end

  def info?
    @info.present? && @info[:label].present? && @info[:link].present?
  end

  def border_style
    return if full_screen
    "rounded-lg"
  end
end
