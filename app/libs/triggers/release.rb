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

  # FIXME: should we take a lock around this train? what is someone double triggers the run?
  def call
    return Response.new(:unprocessable_entity, "Cannot start a train that is not active!") if train.inactive?
    return Response.new(:unprocessable_entity, "Cannot start a train that has no steps. Please add at least one step.") if train.steps.empty?
    return Response.new(:unprocessable_entity, "A release is already in progress!") if train.active_run.present?
    return Response.new(:unprocessable_entity, "Cannot start a new release before wrapping up existing releases!") if train.runs.pending_release?

    if kickoff.ok?
      Response.new(:ok)
    else
      Response.new(:unprocessable_entity, "Could not kickoff a release • #{kickoff.error.message}")
    end
  end

  private

  attr_reader :train, :release, :starting_time
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
    @release =
      train.runs.create!(
        code_name: Haikunator.haikunate(100),
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

    if train.runs.exists?(branch_name:)
      branch_name += "-1"
      branch_name = branch_name.succ while train.runs.exists?(branch_name:)
    end

    branch_name
  end

  def major_release?
    @has_major_bump
  end
end
