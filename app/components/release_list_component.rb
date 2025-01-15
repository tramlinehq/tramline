class ReleaseListComponent < BaseComponent
  include Memery

  REVEAL_HIDE_ACTION = "reveal#hide"
  REVEAL_SHOW_ACTION = "reveal#show"

  def initialize(train:)
    @train = train
    @ongoing_release = train.ongoing_release
    @hotfix_release = train.hotfix_release
    @upcoming_release = train.upcoming_release
  end

  attr_reader :train, :ongoing_release, :hotfix_release, :upcoming_release
  delegate :app, :hotfix_from, to: :train

  # we don't check for train.releases.none?
  # because the constituent releases that are loaded on the page are already memoized, so we avoid a query
  def no_releases?
    previous_releases.empty? && ongoing_release.nil? && upcoming_release.nil? && hotfix_release.nil? && last_completed_release.nil?
  end

  memoize def devops_report
    DevopsReportPresenter.new(train.devops_report)
  end

  memoize def previous_releases
    train
      .releases
      .includes([:release_platform_runs, hotfixed_from: [:release_platform_runs]])
      .completed
      .where.not(id: last_completed_release)
      .order(completed_at: :desc, scheduled_at: :desc)
      .limit(15)
  end

  memoize def last_completed_release
    train.releases.reorder("completed_at DESC").released.first
  end

  def release_startable?
    app.ready? && release_options.present?
  end

  def release_form_partial
    "release_list/#{train.versioning_strategy}_form"
  end

  def release_options
    return [] if train.inactive?
    upcoming_release_startable = train.upcoming_release_startable?
    return [] if train.ongoing_release && !upcoming_release_startable

    start_minor_text = start_release_text
    start_major_text = start_release_text(major: true)
    start_minor_text = start_upcoming_release_text if upcoming_release_startable
    start_major_text = start_upcoming_release_text(major: true) if upcoming_release_startable

    return frozen_version_options(start_release_text) if train.freeze_version

    case train.versioning_strategy
    when "semver" then semver_options(start_major_text, start_minor_text)
    when "calver" then calver_options(start_major_text)
    else raise
    end
  end

  def frozen_version_options(subtitle)
    [
      {
        title: "Fixed version",
        subtitle:,
        icon: "play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "false",
        options: {checked: true, data: {action: REVEAL_HIDE_ACTION}}
      },
      custom_version_option
    ]
  end

  def semver_options(major_subtitle, minor_subtitle)
    [
      {
        title: "Minor",
        subtitle: major_subtitle,
        icon: "play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "false",
        options: {checked: true, data: {action: REVEAL_HIDE_ACTION}}
      },
      {
        title: "Major",
        subtitle: minor_subtitle,
        icon: "forward_step_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "true",
        options: {checked: false, data: {action: REVEAL_HIDE_ACTION}}
      },
      custom_version_option
    ]
  end

  def custom_version_option
    {
      title: "Custom",
      subtitle: "Specify a release version",
      icon: "user_cog_fill.svg",
      opt_name: "has_major_bump",
      opt_value: nil,
      options: {checked: false, data: {action: REVEAL_SHOW_ACTION}}
    }
  end

  def calver_options(subtitle)
    [
      {
        title: "Calendar version",
        subtitle:,
        icon: "play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "true",
        options: {checked: true, data: {action: REVEAL_HIDE_ACTION}}
      },
      custom_version_option
    ]
  end

  def branch_help
    new_branch = Time.current.strftime(train.release_branch_name_fmt(hotfix: false))
    working_branch = train.working_branch
    "Release branch #{new_branch} will be automatically cut from #{working_branch}."
  end

  def ios_enabled?
    app.cross_platform? || app.ios?
  end

  def no_release_empty_state
    if train.automatic?
      if train.activatable?
        {
          title: "Activate the train",
          text: "Once you've activated, we will automatically start running your scheduled releases."
        }
      else
        {
          title: "Upcoming release",
          text: "Your first scheduled release will automatically kick-off at #{train.kickoff_at.to_fs(:short)}. You can also manually run a new release by clicking the prepare button."
        }
      end
    else
      platform = train.release_platforms.first.platform
      text = "You can now start creating new releases. We have added some default submissions settings for you. This involves picking the right workflows and configuring the right channels for build distribution. Please review these before starting a release."
      button_link = edit_app_train_platform_submission_config_path(app, train, platform)
      {
        title: "Create your very first release",
        text:,
        content: render(ButtonComponent.new(scheme: :light, type: :link, label: "Review submission settings", options: button_link, size: :xxs, authz: false))
      }
    end
  end

  def reldex_defined?
    train.release_index.present?
  end

  def release_table_columns
    if reldex_defined?
      ["", "release", "branch", "reldex", "dates", ""]
    else
      ["", "release", "branch", "dates", ""]
    end
  end

  private

  def start_release_text(major: false)
    text =
      if train.freeze_version?
        "Fixed version "
      elsif train.automatic?
        "Manually release version "
      elsif train.calver?
        "Next CalVer will be "
      else
        "Release version "
      end

    version = train.freeze_version? ? train.version_current : train.next_version(major_only: major)
    text + version
  end

  def start_upcoming_release_text(major: false)
    text = "Prepare next "
    text += "release "
    text + train.ongoing_release.next_version(major_only: major)
  end
end
