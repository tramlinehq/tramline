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
module Coordinators
  # TODO: [V2] fixes:
  # start release
  # push processing
  # metadata

  module Signals
    def self.commits_have_landed!(release, head_commit, rest_commits)
      Coordinators::ProcessCommits.call(release, head_commit, rest_commits)
    end

    def self.build_queue_can_be_applied!(build_queue)
      Coordinators::ApplyBuildQueue.call(build_queue)
    end

    def self.workflow_run_finished!(workflow_run_id)
      V2::TriggerSubmissionsJob.perform_later(workflow_run_id)
    end

    def self.internal_release_finished!(build)
      release_platform_run = build.release_platform_run
      if release_platform_run.conf.auto_start_beta_release?
        Coordinators::CreateBetaRelease.call(release_platform_run, build.id, nil)
      end
    end

    def self.regression_testing_is_approved!(build)
      # create beta release here once regression testing is added
    end

    def self.beta_release_is_finished!(build)
      # start soak, or
      Coordinators::StartProductionRelease.call(build.release_platform_run, build.id)
    end

    def self.production_release_is_complete!(release_platform_run)
      Coordinators::FinishPlatformRun.call(release_platform_run)
    end
  end

  module Actions
    Res = GitHub::Result

    def self.start_release!(release)
      # TODO: [V2] trigger a release
      # PreRelease.call(release)
      # NewRelease.call(release)
    end

    def self.process_push_webhook!(release, push_params)
      Res.new { Coordinators::Webhooks::Push.process(release, push_params) }
    end

    def self.process_pull_request_webhook!(release, push_params)
      Res.new { Coordinators::Webhooks::PullRequest.process(release, push_params) }
    end

    def self.apply_build_queue!(build_queue)
      Res.new { Coordinators::ApplyBuildQueue.call(build_queue) }
    end

    def self.save_metadata!(release, metadata)
      # TODO: [V2] save metadata
    end

    def self.start_workflow_run!(workflow_run)
      Res.new do
        raise unless workflow_run.triggering_release.actionable?
        workflow_run.initiate!
      end
    end

    def self.retry_workflow_run!(workflow_run)
      Res.new do
        raise unless workflow_run.triggering_release.actionable?
        workflow_run.retry!
      end
    end

    def self.start_beta_release!(release_platform_run, build_id, commit_id)
      Res.new { Coordinators::CreateBetaRelease.call(release_platform_run, build_id, commit_id) }
    end

    def self.trigger_submission!(submission)
      Res.new do
        raise unless submission.actionable?
        submission.trigger!
      end
    end

    def self.retry_submission!(submission)
      # TODO: retry a submission
    end

    def self.start_new_production_release!(release_platform_run, build_id)
      Res.new { Coordinators::StartProductionRelease.call(release_platform_run, build_id) }
    end

    def self.update_production_build!(submission, build_id)
      Res.new { Coordinators::UpdateBuildOnProduction.call(submission, build_id) }
    end

    def self.prepare_production_submission!(submission)
      Res.new do
        raise unless submission.editable?
        submission.start_prepare!
      end
    end

    def self.start_production_review!(submission)
      Res.new do
        raise unless submission.editable?
        submission.start_submission!
      end
    end

    def self.cancel_production_review!(submission)
      Res.new do
        raise unless submission.editable?
        submission.start_cancellation!
      end
    end

    def self.start_the_store_rollout!(rollout)
      return Res.new { raise } unless rollout.created?
      rollout.start_release!
      return Res.new { raise } if rollout.errors?
      Res.new { true }
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

    def self.complete_release!(release)
      Coordinators::StartFinalizingRelease.call(release, true)
    end
  end
end
