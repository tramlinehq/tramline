class Triggers::Release
  include Memery
  include SiteHttp

  ReleaseAlreadyInProgress = Class.new(StandardError)
  NothingToRelease = Class.new(StandardError)

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
    return Response.new(:unprocessable_entity, "A release is already in progress!") if train.active_run.present?

    if kickoff.ok?
      Response.new(:ok)
    else
      Response.new(:unprocessable_entity, "Could not kickoff a release • #{kickoff.error.message}")
    end
  end

  private

  attr_reader :train, :starting_time, :automatic
  delegate :branching_strategy, to: :train

  memoize def kickoff
    GitHub::Result.new do
      train.with_lock do
        raise ReleaseAlreadyInProgress.new("A release is already in progress!") if train.active_run.present?
        raise NothingToRelease.new("No diff since last release") unless train.diff_since_last_release?
        train.activate! unless train.active?
        create_release
        train.create_webhook!
      end
    end
  end

  def create_release
    train.releases.create!(
      scheduled_at: starting_time,
      branch_name: release_branch,
      release_version: train.version_current,
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
