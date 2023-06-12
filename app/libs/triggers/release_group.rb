class Triggers::ReleaseGroup
  include Memery
  include SiteHttp

  def self.call(train_group, has_major_bump: false)
    new(train_group, has_major_bump:).call
  end

  def initialize(train_group, has_major_bump: false)
    @train_group = train_group
    @ios_train = train_group.ios_train
    @android_train = train_group.android_train
    @starting_time = Time.current
    @has_major_bump = has_major_bump
  end

  def call
    return Response.new(:unprocessable_entity, "Cannot start a train that is not active!") if train_group.inactive?
    return Response.new(:unprocessable_entity, "Cannot start a train that has no steps. Please add at least one step to iOS train.") if @ios_train.steps.empty?
    return Response.new(:unprocessable_entity, "Cannot start a train that has no steps. Please add at least one step to Android train.") if @android_train.steps.empty?
    return Response.new(:unprocessable_entity, "A release is already in progress!") if train_group.active_run.present?
    return Response.new(:unprocessable_entity, "Cannot start a new release before wrapping up existing releases!") if train_group.runs.pending_release?

    if kickoff.ok?
      Response.new(:ok)
    else
      Response.new(:unprocessable_entity, "Could not kickoff a release • #{kickoff.error.message}")
    end
  end

  private

  attr_reader :train_group, :release_group, :starting_time
  delegate :branching_strategy, to: :train_group
  delegate :transaction, to: ApplicationRecord

  memoize def kickoff
    GitHub::Result.new do
      transaction do
        train_group.activate! unless train_group.active?
        create_release
        train_group.create_webhook!
        create_webhook_listeners
      end
    end
  end

  def create_release
    @release_group =
      train_group.runs.create!(
        scheduled_at: starting_time,
        branch_name: release_branch,
        release_version: train_group.version_current,
        has_major_bump: major_release?
      )
  end

  memoize def release_branch
    return new_branch_name if branching_strategy.in?(%w[almost_trunk release_backmerge])
    train_group.release_branch
  end

  def create_webhook_listeners
    train_group.commit_listeners.create(branch_name: release_branch)
  end

  memoize def new_branch_name
    branch_name = starting_time.strftime(train_group.release_branch_name_fmt)

    if train_group.runs.exists?(branch_name:)
      branch_name += "-1"
      branch_name = branch_name.succ while train_group.runs.exists?(branch_name:)
    end

    branch_name
  end

  def major_release?
    @has_major_bump
  end
end
