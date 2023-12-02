class Triggers::Release
  include Memery
  include SiteHttp

  ReleaseAlreadyInProgress = Class.new(StandardError)
  NothingToRelease = Class.new(StandardError)
  AppInDraftMode = Class.new(StandardError)
  UpcomingReleaseNotAllowed = Class.new(StandardError)

  def self.call(train, has_major_bump: false, release_type: "release", new_hotfix_branch: false, automatic: false, hotfix_platform: nil, custom_version: nil)
    new(train, has_major_bump:, release_type:, new_hotfix_branch:, automatic:, hotfix_platform:, custom_version:).call
  end

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
    return Response.new(:unprocessable_entity, "Invalid custom release version! Please use a SemVer like x.y.z format.") if invalid_custom_version?
    return Response.new(:unprocessable_entity, "Could not kickoff a hotfix because the source tag does not exist") if hotfix_from_new_branch? && !hotfix_tag_exists?
    return Response.new(:unprocessable_entity, "Could not kickoff a hotfix because the source release branch does not exist") if hotfix_from_previous_branch? && !hotfix_branch_exists?
    return Response.new(:unprocessable_entity, "Cannot start a train that is not active!") if train.inactive?
    return Response.new(:unprocessable_entity, "Cannot start a train that has no release step. Please add at least one release step to the train.") unless train.release_platforms.all?(&:has_release_step?)
    return Response.new(:unprocessable_entity, "No more releases can be started until the ongoing release is finished!") if train.ongoing_release.present? && automatic
    return Response.new(:unprocessable_entity, "No more releases can be started until the ongoing release is finished!") if train.upcoming_release.present?
    return Response.new(:unprocessable_entity, "Upcoming releases are not allowed for your train.") if train.ongoing_release.present? && !train.upcoming_release_startable?
    return Response.new(:unprocessable_entity, "App is in draft mode, cannot start a release!") if train.app.in_draft_mode?
    return Response.new(:unprocessable_entity, "Hotfix platform - #{hotfix_platform} is not valid!") if invalid_hotfix_platform?

    if kickoff.ok?
      Response.new(:ok, release)
    else
      Response.new(:unprocessable_entity, "Could not kickoff a release • #{kickoff.error.message}")
    end
  end

  private

  attr_reader :train, :starting_time, :automatic, :release, :release_type, :new_hotfix_branch, :hotfix_platform, :custom_version
  delegate :branching_strategy, :hotfix_from, to: :train

  memoize def kickoff
    GitHub::Result.new do
      train.with_lock do
        raise AppInDraftMode.new("App is in draft mode, cannot start a release!") if train.app.in_draft_mode?
        raise ReleaseAlreadyInProgress.new("No more releases can be started until the ongoing release is finished!") if train.ongoing_release.present? && automatic
        raise ReleaseAlreadyInProgress.new("No more releases can be started until the ongoing release is finished!") if train.upcoming_release.present?
        raise UpcomingReleaseNotAllowed.new("Upcoming releases are not allowed for your train.") if train.ongoing_release.present? && !train.upcoming_release_startable?
        raise NothingToRelease.new("No diff since last release") if regular_release? && !train.diff_since_last_release?
        train.activate! unless train.active?
        create_release
        train.create_webhook!
      end
    end
  end

  def create_release
    @release ||= train.releases.create!(
      scheduled_at: starting_time,
      branch_name: release_branch,
      has_major_bump: major_release?,
      is_automatic: automatic,
      release_type: release_type,
      hotfixed_from: hotfix_from,
      new_hotfix_branch: new_hotfix_branch,
      hotfix_platform: (hotfix_platform if hotfix?),
      custom_version: custom_version
    )
  end

  def release_branch
    return new_branch_name(hotfix: true) if hotfix_from_new_branch? && create_branches?
    return existing_hotfix_branch if hotfix_from_previous_branch?
    return new_branch_name if create_branches?
    train.release_branch
  end

  memoize def new_branch_name(hotfix: false)
    branch_name = starting_time.strftime(train.release_branch_name_fmt(hotfix:))

    if train.releases.exists?(branch_name:)
      branch_name += "-1"
      branch_name = branch_name.succ while train.releases.exists?(branch_name:)
    end

    branch_name
  end

  def major_release?
    @has_major_bump
  end

  def hotfix?
    release_type == "hotfix"
  end

  def regular_release?
    release_type == "release"
  end

  def create_branches?
    branching_strategy.in?(%w[almost_trunk release_backmerge])
  end

  def new_hotfix_branch?
    new_hotfix_branch
  end

  memoize def hotfix_branch_exists?
    train.vcs_provider.branch_exists?(existing_hotfix_branch)
  end

  memoize def hotfix_tag_exists?
    existing_hotfix_tag.present? && train.vcs_provider.tag_exists?(existing_hotfix_tag)
  end

  def hotfix_from_new_branch?
    hotfix? && new_hotfix_branch?
  end

  def hotfix_from_previous_branch?
    hotfix? && !new_hotfix_branch?
  end

  def existing_hotfix_tag
    hotfix_from.tag_name
  end

  def existing_hotfix_branch
    hotfix_from.branch_name
  end

  def invalid_hotfix_platform?
    hotfix? && hotfix_platform.present? && !hotfix_platform.in?(ReleasePlatform.platforms.values)
  end

  def invalid_custom_version?
    return false if custom_version.blank?
    VersioningStrategies::Semverish.new(custom_version)
    false
  rescue ArgumentError
    true
  end
end
