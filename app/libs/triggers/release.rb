class Triggers::Release
  include Memery
  include SiteHttp

  def self.call(train, has_major_bump: false)
    new(train, has_major_bump:).call
  end

  def initialize(train, has_major_bump: false)
    @train = train
    @starting_time = Time.current
    @has_major_bump = has_major_bump
  end

  def call
    return Response.new(:unprocessable_entity, "Cannot start a train that is not active!") if train.inactive?
    return Response.new(:unprocessable_entity, "Cannot start a train that has no release step. Please add at least one release step to the train.") if train.release_platforms.any?(&:has_release_step?)
    return Response.new(:unprocessable_entity, "A release is already in progress!") if train.active_run.present?

    if kickoff.ok?
      Response.new(:ok)
    else
      Response.new(:unprocessable_entity, "Could not kickoff a release • #{kickoff.error.message}")
    end
  end

  private

  attr_reader :train, :starting_time
  delegate :branching_strategy, to: :train
  delegate :transaction, to: ApplicationRecord

  memoize def kickoff
    GitHub::Result.new do
      transaction do
        train.activate! unless train.active?
        create_release
        train.create_webhook!
        create_webhook_listeners
      end
    end
  end

  def create_release
    train.releases.create!(
      scheduled_at: starting_time,
      branch_name: release_branch,
      release_version: train.version_current,
      has_major_bump: major_release?
    )
  end

  memoize def release_branch
    return new_branch_name if branching_strategy.in?(%w[almost_trunk release_backmerge])
    train.release_branch
  end

  def create_webhook_listeners
    train.commit_listeners.create(branch_name: release_branch)
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
