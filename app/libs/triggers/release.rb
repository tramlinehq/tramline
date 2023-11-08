class Triggers::Release
  include Memery
  include SiteHttp

  ReleaseAlreadyInProgress = Class.new(StandardError)
  NothingToRelease = Class.new(StandardError)
  AppInDraftMode = Class.new(StandardError)
  UpcomingReleaseNotAllowed = Class.new(StandardError)

  def self.call(train, has_major_bump: false, release_type: "release", new_hotfix_branch: false, automatic: false)
    new(train, has_major_bump:, release_type:, new_hotfix_branch:, automatic:).call
  end

  def initialize(train, has_major_bump: false, release_type: "release", new_hotfix_branch: false, automatic: false)
    @train = train
    @starting_time = Time.current
    @has_major_bump = has_major_bump
    @automatic = automatic
    @release_type = release_type
    @new_hotfix_branch = new_hotfix_branch
  end

  def call
    return Response.new(:unprocessable_entity, "Cannot start a train that is not active!") if train.inactive?
    return Response.new(:unprocessable_entity, "Cannot start a train that has no release step. Please add at least one release step to the train.") unless train.release_platforms.all?(&:has_release_step?)
    return Response.new(:unprocessable_entity, "No more releases can be started until the ongoing release is finished!") if train.ongoing_release.present? && automatic
    return Response.new(:unprocessable_entity, "No more releases can be started until the ongoing release is finished!") if train.upcoming_release.present?
    return Response.new(:unprocessable_entity, "Upcoming releases are not allowed for your train.") if train.ongoing_release.present? && !train.upcoming_release_startable?
    return Response.new(:unprocessable_entity, "App is in draft mode, cannot start a release!") if train.app.in_draft_mode?

    if kickoff.ok?
      Response.new(:ok, release)
    else
      Response.new(:unprocessable_entity, "Could not kickoff a release • #{kickoff.error.message}")
    end
  end

  private

  attr_reader :train, :starting_time, :automatic, :release, :release_type, :new_hotfix_branch
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
      new_hotfix_branch: new_hotfix_branch
    )
  end

  def release_branch
    return new_branch_name(hotfix: true) if hotfix? && new_hotfix_branch? && create_branches?
    return existing_hotfix_branch_name if hotfix? && !new_hotfix_branch? && create_branches?
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

  def existing_hotfix_branch_name
    existing_branch = hotfix_from.branch_name
    return existing_branch if train.vcs_provider.branch_exists?(existing_branch)
    new_branch_name(hotfix: true)
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
end
