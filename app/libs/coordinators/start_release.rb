class Coordinators::StartRelease
  include Memery

  def self.call(train, **release_params)
    new(train, **release_params).call
  end

  ReleaseAlreadyInProgress = Class.new(StandardError)
  NothingToRelease = Class.new(StandardError)
  AppInDraftMode = Class.new(StandardError)
  UpcomingReleaseNotAllowed = Class.new(StandardError)

  def initialize(train, has_major_bump: false, release_type: "release", new_hotfix_branch: false, automatic: false, hotfix_platform: nil, custom_version: nil)
    @train = train
    @starting_time = Time.current
    @has_major_bump = has_major_bump
    @automatic = automatic
    @release_type = release_type
    @new_hotfix_branch = new_hotfix_branch
    @hotfix_platform = hotfix_platform
    @custom_version = custom_version
  end

  def call
    raise "Invalid custom release version! Please use a SemVer-like x.y.z format based on your configured versioning strategy." if invalid_custom_version?
    raise "Could not kickoff a hotfix because the source tag does not exist" if hotfix_from_new_branch? && !hotfix_tag_exists?
    raise "Could not kickoff a hotfix because the source release branch does not exist" if hotfix_from_previous_branch? && !hotfix_branch_exists?
    raise "Cannot start a train that is not active!" if train.inactive?
    raise "No more releases can be started until the ongoing release is finished!" if train.upcoming_release.present? && !hotfix?
    raise "Upcoming releases are not allowed for your train." if train.ongoing_release.present? && !train.upcoming_release_startable? && !hotfix?
    raise "App is in draft mode, cannot start a release to public channels!" if train.app.in_draft_mode? && train.has_restricted_public_channels?
    raise "Hotfix platform - #{hotfix_platform} is not valid!" if invalid_hotfix_platform?

    kickoff
    Coordinators::Signals.release_has_started!(release)
    release
  end

  attr_reader :train, :starting_time, :automatic, :release, :release_type, :new_hotfix_branch, :hotfix_platform, :custom_version
  delegate :branching_strategy, :hotfix_from, to: :train

  def kickoff
    train.with_lock do
      raise AppInDraftMode.new("App is in draft mode, cannot start a release!") if train.app.in_draft_mode?
      raise ReleaseAlreadyInProgress.new("No more releases can be started until the ongoing release is finished!") if train.upcoming_release.present? && !hotfix?
      raise UpcomingReleaseNotAllowed.new("Upcoming releases are not allowed for your train.") if train.ongoing_release.present? && !train.upcoming_release_startable? && !hotfix?
      raise NothingToRelease.new("No diff since last release") if regular_release? && !train.diff_since_last_release?
      raise NothingToRelease.new("No diff between working and release branch") if train.parallel_working_branch? && !train.diff_for_release?
      train.activate! unless train.active?
      create_release
      train.create_webhook!
    end
  end

  def create_release
    @release ||= train.releases.create!(
      scheduled_at: starting_time,
      branch_name: release_branch,
      is_automatic: automatic,
      release_type: release_type,
      hotfixed_from: hotfix_from,
      new_hotfix_branch: new_hotfix_branch,
      hotfix_platform: (hotfix_platform if hotfix?),
      original_release_version: new_release_version,
      release_pilot_id: Current.user&.id
    )
  end

  def release_branch
    return build_branch_name(hotfix: true) if hotfix_from_new_branch? && create_branches?
    return existing_hotfix_branch if hotfix_from_previous_branch?
    return build_branch_name if create_branches?
    train.release_branch
  end

  memoize def build_branch_name(hotfix: false)
    substitution_tokens = {
      trainName: train.display_name,
      releaseStartDate: starting_time,
      releaseVersion: new_release_version
    }
    branch_name = train.release_branch_name_fmt(hotfix:, substitution_tokens:)

    if train.releases.exists?(branch_name:)
      branch_name += "-1"
      branch_name = branch_name.succ while train.releases.exists?(branch_name:)
    end

    branch_name
  end

  def create_branches? = branching_strategy.in?(%w[almost_trunk release_backmerge])

  def hotfix? = (release_type == "hotfix")

  def regular_release? = (release_type == "release")

  def existing_hotfix_branch = hotfix_from.branch_name

  def existing_hotfix_tag = hotfix_from.tag_name

  def new_hotfix_branch? = new_hotfix_branch

  def hotfix_from_previous_branch? = hotfix? && !new_hotfix_branch?

  def hotfix_from_new_branch? = hotfix? && new_hotfix_branch?

  def invalid_hotfix_platform?
    hotfix? && hotfix_platform.present? && !hotfix_platform.in?(ReleasePlatform.platforms.values)
  end

  memoize def hotfix_branch_exists?
    train.vcs_provider.branch_exists?(existing_hotfix_branch)
  end

  memoize def hotfix_tag_exists?
    existing_hotfix_tag.present? && train.vcs_provider.tag_exists?(existing_hotfix_tag)
  end

  memoize def new_release_version
    return custom_version if custom_version.present?
    return train.version_current if train.freeze_version?
    return train.hotfix_from&.next_version(patch_only: hotfix?) if hotfix?
    (train.ongoing_release.presence || train.hotfix_release.presence || train).next_version(major_only: @has_major_bump)
  end

  def invalid_custom_version?
    return false if custom_version.blank?
    VersioningStrategies::Semverish.new(custom_version).invalid?(strategy: train.versioning_strategy)
  rescue ArgumentError
    true
  end
end
