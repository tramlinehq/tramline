class Triggers::Release
  include Memery
  include SiteHttp

  RELEASE_HANDLERS = {
    "almost_trunk" => AlmostTrunk,
    "parallel_working" => ParallelBranches,
    "release_backmerge" => ReleaseBackMerge
  }

  def self.call(train)
    new(train).call
  end

  def initialize(train)
    @train = train
    @starting_time = Time.current
  end

  # FIXME: should we take a lock around this train? what is someone double triggers the run?
  def call
    return Response.new(:unprocessable_entity, "Cannot start a train that is inactive!") if train.inactive?
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
        create_release
        create_webhooks.value!
        create_webhook_listeners
        RELEASE_HANDLERS[branching_strategy].call(release, release_branch).value!
      end
    end
  end

  def create_release
    @release =
      train.runs.create(
        code_name: Haikunator.haikunate(100),
        scheduled_at: starting_time,
        branch_name: release_branch,
        release_version: train.version_current
      )
  end

  # Webhooks are created with the train and we don't need to create webhooks for each train run AKA release
  # This is a fallback to ensure that webhook gets created if it is not present against the train
  def create_webhooks
    GitHub::Result.new do
      train.vcs_provider.create_webhook!(train_id: train.id)
    rescue Installations::Errors::HookAlreadyExistsOnRepository
      nil
    end
  end

  def create_webhook_listeners
    train.commit_listeners.create(branch_name: release_branch)
  end

  memoize def release_branch
    return new_branch_name if branching_strategy.in?(%w[almost_trunk release_backmerge])
    train.release_branch
  end

  memoize def new_branch_name
    branch_name = starting_time.strftime(train.release_branch_name_fmt)

    if train.runs.exists?(branch_name:)
      branch_name += "-1"
      branch_name = branch_name.succ while train.runs.exists?(branch_name:)
    end

    branch_name
  end
end
