class V2::LiveRelease::ContainerComponent < V2::BaseReleaseComponent
  renders_one :back_button, -> { V2::BackButtonComponent.new(path: app_train_releases_path(release.app, release.train), to: "the train") }
  renders_many :tabs, V2::LiveRelease::StepComponent

  SELECTED_TAB_STYLE = "active text-main bg-white border-l-3"
  TAB_STATUS_ICON = {
    none: {icon: "v2/circle.svg", classes: STATUS_COLOR_PALETTE[:neutral].join(" ") + " !bg-backgroundLight-50"},
    blocked: {icon: "v2/circle_x.svg", classes: STATUS_COLOR_PALETTE[:inert].join(" ")},
    ongoing: {icon: "v2/circle_dashed.svg", classes: STATUS_COLOR_PALETTE[:ongoing].join(" ")},
    success: {icon: "v2/circle_check_big.svg", classes: STATUS_COLOR_PALETTE[:success].join(" ")}
  }

  def initialize(release, title:, error_resource: nil)
    @release = release
    @title = title
    @error_resource = error_resource
    super(@release)
  end

  attr_reader :title, :error_resource, :release
  delegate :live_release_tab_configuration, :current_overall_status, to: :helpers

  def overall_status
    RELEASE_PHASE.fetch(current_overall_status.to_sym)
  end

  def sorted_sections
    live_release_tab_configuration.to_h do |s, configs|
      [s, configs.sort_by { |_, c| c[:position] }]
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
    TAB_STATUS_ICON[config[:status]] => {icon:, classes:}
    render V2::IconComponent.new(icon, size: :md, classes:)
  end

  def sidebar_title_tag(config)
    config[:unavailable] ? :div : :a
  end

  # TODO: [V2] use the new rollout domain object
  memoize def staged_rollout_status(platform_run)
    latest_store_release = platform_run.store_releases.first
    return unless latest_store_release&.staged_rollout?

    staged_rollout = latest_store_release.staged_rollout
    return if staged_rollout.blank?

    percentage = ""

    if staged_rollout.last_rollout_percentage.present?
      formatter = (staged_rollout.last_rollout_percentage % 1 == 0) ? "%.0f" : "%.02f"
      percentage = formatter % staged_rollout.last_rollout_percentage
    end

    status = (staged_rollout.completed? || staged_rollout.fully_released?) ? :success : :ongoing

    {text: "#{percentage}% rollout", status:}
  end
end
