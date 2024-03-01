class V2::ReleaseListComponent < V2::BaseComponent
  include Memery

  def initialize(train:)
    @train = train
    @ongoing_release = train.ongoing_release
    @hotfix_release = train.hotfix_release
    @upcoming_release = train.upcoming_release
  end

  attr_reader :train, :ongoing_release, :hotfix_release, :upcoming_release
  delegate :app, :devops_report, :hotfix_from, to: :train

  def empty?
    previous_releases.empty? && ongoing_release.nil? && upcoming_release.nil? && hotfix_release.nil? && last_completed_release.nil?
  end

  memoize def previous_releases
    train
      .releases
      .includes([:release_platform_runs, hotfixed_from: [:release_platform_runs]])
      .completed
      .where.not(id: last_completed_release)
      .order(completed_at: :desc, scheduled_at: :desc)
      .limit(10)
  end

  memoize def last_completed_release
    train.releases.reorder("completed_at DESC").released.first
  end

  def release_component(run)
    V2::BaseReleaseComponent.new(run)
  end

  def release_options
    return [] unless train.manually_startable?
    return [] if train.ongoing_release && !train.upcoming_release_startable?

    start_minor_text = start_release_text
    start_major_text = start_release_text(major: true)
    start_minor_text = start_upcoming_release_text if train.upcoming_release_startable?
    start_major_text = start_upcoming_release_text(major: true) if train.upcoming_release_startable?

    [
      {
        title: "Minor",
        subtitle: start_minor_text,
        icon: "v2/play_empty.svg",
        opt_name: "has_major_bump",
        opt_value: "false",
        options: {checked: true, data: {action: "reveal#hide"}}
      },
      {
        title: "Major",
        subtitle: start_major_text,
        icon: "v2/fast_forward.svg",
        opt_name: "has_major_bump",
        opt_value: "true",
        options: {checked: false, data: {action: "reveal#hide"}}
      },
      {
        title: "Custom",
        subtitle: "Specify a release version",
        icon: "v2/user_cog.svg",
        opt_name: "has_major_bump",
        opt_value: nil,
        options: {checked: false, data: {action: "reveal#show"}}
      }
    ]
  end

  def ios_enabled?
    train.app.cross_platform? || train.app.ios?
  end

  private

  def start_release_text(major: false)
    text = train.automatic? ? "Manually release version " : "Release version "
    text + train.next_version(major_only: major)
  end

  def start_upcoming_release_text(major: false)
    text = "Prepare next "
    text += "release "
    text + train.ongoing_release.next_version(major_only: major)
  end
end
