class Triggers::Release
  include Memery
  include SiteHttp

  ReleaseAlreadyInProgress = Class.new(StandardError)
  NothingToRelease = Class.new(StandardError)
  AppInDraftMode = Class.new(StandardError)
  UpcomingReleaseNotAllowed = Class.new(StandardError)

  def self.call(train, has_major_bump: false, automatic: false)
    new(train, has_major_bump:, automatic:).call
  end

  def initialize(train, has_major_bump: false, automatic: false)
    @train = train
    @starting_time = Time.current
    @has_major_bump = has_major_bump
    @automatic = automatic
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

  attr_reader :train, :starting_time, :automatic, :release
  delegate :branching_strategy, to: :train

  memoize def kickoff
    GitHub::Result.new do
      train.with_lock do
        raise AppInDraftMode.new("App is in draft mode, cannot start a release!") if train.app.in_draft_mode?
        raise ReleaseAlreadyInProgress.new("No more releases can be started until the ongoing release is finished!") if train.ongoing_release.present? && automatic
        raise ReleaseAlreadyInProgress.new("No more releases can be started until the ongoing release is finished!") if train.upcoming_release.present?
        raise UpcomingReleaseNotAllowed.new("Upcoming releases are not allowed for your train.") if train.ongoing_release.present? && !train.upcoming_release_startable?
        raise NothingToRelease.new("No diff since last release") unless train.diff_since_last_release?
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
      is_automatic: automatic
    )
  end

  memoize def release_branch
    return new_branch_name if branching_strategy.in?(%w[almost_trunk release_backmerge])
    train.release_branch
  end

  memoize def new_branch_name
    branch_name = starting_time.strftime(train.release_branch_name_fmt)

    if train.releases.exists?(branch_name:)
      branch_name += "-1"
      branch_name = branch_name.succ while train.releases.exists?(branch_name:)
    end

    branch_name
  end

  def major_release?
    @has_major_bump
  end
end
