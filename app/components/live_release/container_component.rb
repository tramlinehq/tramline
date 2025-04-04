class LiveRelease::ContainerComponent < BaseComponent
  renders_one :back_button, -> { BackButtonComponent.new(path: app_train_releases_path(release.app, release.train), to: "the train") }
  renders_many :tabs, LiveRelease::StepComponent

  RELEASE_PHASE = {
    completed: ["Complete", :success],
    finishing: ["Finishing up", :success],
    kickoff: ["Kickoff", :routine],
    stabilization: ["Stabilizing the release", :routine],
    review: ["Under store review", :ongoing],
    rollout: ["Rolling out to users", :inert],
    approvals: ["Requires approvals", :inert],
    stopped: ["Stopped", :failure],
    pre_release_started: ["Preparing the release", :routine],
    pre_release_failed: ["Could not prepare release", :inert]
  }
  SELECTED_TAB_STYLE = "active text-main bg-main-100 border-l-2 border-main-400"
  TAB_STATUS_ICON = {
    none: {icon: "circle_dashed.svg", classes: STATUS_COLOR_PALETTE[:neutral].join(" ") + " !bg-backgroundLight-50"},
    blocked: {icon: "circle_x.svg", classes: STATUS_COLOR_PALETTE[:inert].join(" ")},
    ongoing: {icon: "circle_dashed.svg", classes: STATUS_COLOR_PALETTE[:ongoing].join(" ") + " animate-pulse"},
    success: {icon: "circle_check_big.svg", classes: STATUS_COLOR_PALETTE[:success].join(" ")},
    unblocked: {icon: "circle_dashed.svg", classes: STATUS_COLOR_PALETTE[:ongoing].join(" ")}
  }
  RIGHT_GUTTER = "pr-4"

  def initialize(release, title:, error_resource: nil)
    @release = ReleasePresenter.new(release, self)
    @title = title
    @error_resource = error_resource
  end

  attr_reader :title, :error_resource, :release
  delegate :cross_platform?,
    :hotfix?,
    :display_release_version,
    :finished?,
    :active?,
    :partially_finished?,
    :release_branch,
    :reldex,
    :tag_name,
    :platform,
    :automatic?,
    :scheduled_badge,
    :stop_release_warning, to: :release

  def overall_status
    RELEASE_PHASE.fetch(live_release_overall_status.to_sym)
  end

  def sorted_sections
    live_release_tab_configuration.to_h do |s, configs|
      [
        s.to_s.humanize,
        configs.reject { |_, c| c[:status] == :hidden }.sort_by { |_, c| c[:position] }
      ]
    end
  end

  def active_style(tab_path)
    SELECTED_TAB_STYLE if current_page?(tab_path)
  end

  def coming_soon(config)
    return unless config[:unavailable]

    render IconComponent.new("construction.svg", size: :md) do |icon|
      icon.with_tooltip("This feature is coming soon!", placement: "top", cursor: false)
    end
  end

  def status_icon(config)
    TAB_STATUS_ICON[config[:status]] => {icon:, classes:}
    render IconComponent.new(icon, size: :md, classes:)
  end

  def sidebar_title_tag(config)
    config[:unavailable] ? :div : :a
  end

  def hotfix_background
    "bg-diagonal-stripes-soft-red" if hotfix?
  end
end
