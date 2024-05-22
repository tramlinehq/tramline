class V2::LiveRelease::ContainerComponent < V2::BaseReleaseComponent
  renders_one :back_button, V2::BackButtonComponent
  renders_many :tabs, ->(**args) { V2::LiveRelease::StepComponent.new(frame: @frame, **args) }

  SELECTED_TAB_STYLE = "active text-main bg-white border-l-3"

  def initialize(release, title:, turbo_frame:, tab_config: [], error_resource: nil)
    raise ArgumentError, "tab_config must be a Hash" unless tab_config.is_a?(Hash)

    @release = release
    @title = title
    @tab_config = tab_config
    @turbo_frame = turbo_frame
    @error_resource = error_resource
    super(@release)
  end

  attr_reader :title, :tab_config, :error_resource, :release

  def frame = @turbo_frame

  def sorted_sections
    tab_config.to_h do |s, configs|
      [s, configs.sort_by { |_, c| c[:position] }]
    end
  end

  def status_color(status)
    case status
    when :success then "bg-green-500"
    when :ongoing then "bg-amber-500"
    when :none then "bg-backgroundLight-50"
    else
      raise ArgumentError, "Invalid status: #{status}"
    end
  end

  def active_style(tab_path)
    SELECTED_TAB_STYLE if current_page?(tab_path)
  end

  def coming_soon(config)
    return unless config[:unavailable]

    render V2::IconComponent.new("v2/construction.svg", size: :md) do |icon|
      icon.with_tooltip("This feature is coming soon!", placement: "top", cursor: false)
    end
  end

  def status_icon(config)
    if config[:status] == :blocked
      render V2::IconComponent.new("v2/circle_x.svg", size: :md)
    else
      content_tag(:div, nil, class: "w-4 h-3.5 #{status_color(config[:status])} rounded-full border-2 border-main-500 dark:border-gray-900 dark:bg-gray-700")
    end
  end

  def sidebar_title_tag(config)
    config[:unavailable] ? :div : :a
  end
end
