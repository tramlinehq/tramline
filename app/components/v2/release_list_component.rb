class V2::ReleaseListComponent < V2::BaseComponent
  include Memery

  def initialize(train:)
    @train = train
  end

  attr_reader :train

  delegate :app, :devops_report, :hotfix_from, to: :train

  def empty?
    previous_releases.empty? &&
      ongoing_release.nil? &&
      upcoming_release.nil? &&
      hotfix_release.nil? &&
      last_completed_release.nil?
  end

  memoize def previous_releases
    train
      .releases
      .completed
      .order(scheduled_at: :desc)
      .where.not(id: last_completed_release)
      .take(10)
  end

  memoize def last_completed_release
    train.releases.released.first
  end

  memoize def ongoing_release = train.ongoing_release

  memoize def hotfix_release = train.hotfix_release

  memoize def upcoming_release = train.upcoming_release

  def ordered_releases
    train.releases.order(scheduled_at: :desc).take(100)
  end

  def release_component(run)
    V2::BaseReleaseComponent.new(run)
  end

  def release_options
    if train.ongoing_release && train.upcoming_release_startable?
      [
        {
          title: "Minor",
          subtitle: start_upcoming_release_text,
          icon: "v2/play-empty.svg",
          opt_name: "has_major_bump",
          opt_value: true,
          checked: true,
          options: {data: {action: "reveal#hide"}}
        },
        {
          title: "Major",
          subtitle: start_upcoming_release_text(major: true),
          icon: "v2/fast_forward.svg",
          opt_name: "has_major_bump",
          opt_value: true,
          checked: false,
          options: {data: {action: "reveal#hide"}}
        },
        {
          title: "Custom",
          subtitle: "Specify a release version",
          icon: "v2/user_cog.svg",
          opt_name: "has_major_bump",
          opt_value: true,
          checked: false,
          options: {data: {action: "reveal#show"}}
        }
      ]
    elsif @train.manually_startable?
      [
        {
          title: "Minor",
          subtitle: start_release_text,
          icon: "v2/play-empty.svg",
          opt_name: "has_major_bump",
          opt_value: false,
          checked: true,
          options: {data: {action: "reveal#hide"}}
        },
        {
          title: "Major",
          subtitle: start_release_text(major: true),
          icon: "v2/fast_forward.svg",
          opt_name: "has_major_bump",
          opt_value: true,
          checked: false,
          options: {data: {action: "reveal#hide"}}
        },
        {
          title: "Custom",
          subtitle: "Specify a release version",
          icon: "v2/user_cog.svg",
          opt_name: "has_major_bump",
          opt_value: true,
          checked: false,
          options: {data: {action: "reveal#show"}}
        }
      ]
    end
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
