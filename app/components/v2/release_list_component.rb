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

  def release_startable?
    app.ready? && release_options.present?
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
        icon: "v2/play_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "false",
        options: {checked: true, data: {action: "reveal#hide"}}
      },
      {
        title: "Major",
        subtitle: start_major_text,
        icon: "v2/forward_step_fill.svg",
        opt_name: "has_major_bump",
        opt_value: "true",
        options: {checked: false, data: {action: "reveal#hide"}}
      },
      {
        title: "Custom",
        subtitle: "Specify a release version",
        icon: "v2/user_cog_fill.svg",
        opt_name: "has_major_bump",
        opt_value: nil,
        options: {checked: false, data: {action: "reveal#show"}}
      }
    ]
  end

  def ios_enabled?
    app.cross_platform? || app.ios?
  end

  def empty_state
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
      {
        title: "Create your very first release",
        text: "Once you've finished configuring your train fully, you can start creating new releases."
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
    text = train.automatic? ? "Manually release version " : "Release version "
    text + train.next_version(major_only: major)
  end

  def start_upcoming_release_text(major: false)
    text = "Prepare next "
    text += "release "
    text + train.ongoing_release.next_version(major_only: major)
  end
end
