# This module is a collection of high-level events for a release
#
#                    ┌────────────────────────┐
#                  ┌─│  Release Platform Run  │──┐
#                  │ └────────────────────────┘  │
#                  │              │              │
#                  ▼              │              ▼
#     ┏━━━━━━━━━━━━━━━━━━━━━━━━┓  │ ┏━━━━━━━━━━━━━━━━━━━━━━━━┓
#     ┃   Pre-Prod Releases    ┃  │ ┃                        ┃
#  ┌──┃                        ┃▒ │ ┃  Production Releases   ┃──┐
#  │  ┃   (Internal / Beta)    ┃▒ │ ┃                        ┃▒ │
#  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━┛▒ │ ┗━━━━━━━━━━━━━━━━━━━━━━━━┛▒ │
#  │   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
#  │   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
#  │             ┌──────────────┐ │  ┌──────────────┐           │
#  │             │ Workflow Run │ │  │    Build     │◀──────────┤
#  │ ┌───────────┼──────────────┤ │  └──────────────┘           │
#  │ │   Build   │              │ │  ┌────────────────────────┐ │
#  │ │ Metadata  │    Build     │ │  │ Release Health Metrics │ │
#  │ └───────────┴──────────────┘ │  └────────────────────────┘ │
#  │                     │        │               ▲             │
#  │                     │        │               │             │
#  │                     ▼        │               └─────────────┤
#  │             ┌──────────────┐ │  ┌──────────────┐           │
#  │             │ Submissions  │ │  │ Submissions  │           │
#  │             ├──────────────┤ │  ├──────────────┤           │
#  │             │   Rollout    │ │  │   Rollout    │◀──────────┘
#  │             └──────────────┘ ▼  └──────────────┘
#  │                 ┌────────────────────────┐
#  └────────────────▶│   Regression Testing   │
#                    └────────────────────────┘
#
# == It ought to be used in the following way ==
# • At the boundaries of user input or external events (controllers, api listeners)
# • To listen to signals from terminal states in a live release
#
# == Note ==
# • All subsequent dispatch work is kicked off from this point.
# • This does not replace internal state machines of other sub-models.
# • It currently does not have any state of its own.
module Coordinators::Signals
  Res = GitHub::Result

  def self.start_release!(release)
    # PreRelease.call(release)
    # NewRelease.call(release)
  end

  def self.new_commit_has_landed!(release, commit)
    # check if patchfix/hotfix etc
    # check if we need to trigger rc
    Coordinators::ProcessCommit.call(release, commit)
  end

  def self.workflow_run_finished!(workflow_run) # TODO: pass id only
    V2::CreateBuildJob.perform_later(workflow_run.id)
  end

  def self.build_is_available_for_regression_testing!(build)
    # StartRegressionTesting.call(build)
  end

  def self.regression_testing_is_approved!(build)
    # StartBetaRelease.call(build)
  end

  def self.increase_the_store_rollout!(rollout)
    return Res.new { raise } unless rollout.started?
    rollout.move_to_next_stage!
    return Res.new { raise } if rollout.errors?
    Res.new { true }
  end

  def self.pause_the_store_rollout!(rollout)
    return Res.new { raise } unless rollout.started?
    rollout.pause_release!
    return Res.new { raise } if rollout.errors?
    Res.new { true }
  end

  def self.resume_the_store_rollout!(rollout)
    return Res.new { raise } unless rollout.halted?
    rollout.resume_release!
    return Res.new { raise } if rollout.errors?
    Res.new { true }
  end

  def self.halt_the_store_rollout!(rollout)
    return Res.new { raise } unless rollout.started?
    rollout.halt_release!
    return Res.new { raise } if rollout.errors?
    Res.new { true }
  end

  def self.fully_release_the_store_rollout!(rollout)
    return Res.new { raise } unless rollout.started?
    rollout.release_fully!
    return Res.new { raise } if rollout.errors?
    Res.new { true }
  end

  def self.beta_release_is_complete!(build)
    # start soak, or
    Coordinators::StartProductionRelease.call(build)
  end

  def self.beta_release_is_available!(build)
    # start soak, or
    Coordinators::StartProductionRelease.call(build)
  end

  def self.production_release_is_complete!(release_platform_run)
    Coordinators::FinishProductionRelease.call(release_platform_run)
  end

  def self.entire_release_is_complete!(release_id, force_finalize = false)
    V2::FinalizeReleaseJob.perform_later(release_id, force_finalize)
  end
end
