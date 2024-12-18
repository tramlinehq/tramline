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
  # metadata

  module Signals
    def self.release_has_started!(release)
      release.notify!("New release has commenced!", :release_started, release.notification_params)
      Releases::PreReleaseJob.perform_later(release.id)
      Releases::FetchCommitLogJob.perform_later(release.id)
      RefreshReportsJob.perform_later(release.hotfixed_from.id) if release.hotfix?
    end

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
      # manage regression testing here
    end

    def self.regression_testing_is_approved!(build)
      # create beta release here once regression testing is added
    end

    def self.beta_release_is_finished!(build)
      # start soak, or
      release_platform_run = build.release_platform_run
      if release_platform_run.conf.production_release.present?
        Coordinators::StartProductionRelease.call(release_platform_run, build.id)
      else
        Coordinators::FinishPlatformRun.call(release_platform_run)
      end
    end

    def self.production_release_is_complete!(release_platform_run)
      Coordinators::FinishPlatformRun.call(release_platform_run)
    end
  end

  module Actions
    Res = GitHub::Result

    def self.start_release!(train, **release_params)
      Res.new { Coordinators::StartRelease.call(train, **release_params) }
    end

    def self.process_push_webhook(train, push_params)
      Res.new { Coordinators::Webhooks::Push.process(train, push_params) }
    end

    def self.process_pull_request_webhook(train, pull_request_params)
      Res.new { Coordinators::Webhooks::PullRequest.process(train, pull_request_params) }
    end

    def self.apply_build_queue!(build_queue)
      Res.new { Coordinators::ApplyBuildQueue.call(build_queue) }
    end

    def self.save_metadata!(release, metadata)
      # TODO: [V2] save metadata
    end

    def self.start_workflow_run!(workflow_run)
      Res.new do
        raise "release is not actionable" unless workflow_run.triggering_release.actionable?
        workflow_run.initiate!
      end
    end

    def self.retry_workflow_run!(workflow_run)
      Res.new do
        raise "release is not actionable" unless workflow_run.triggering_release.actionable?
        raise "workflow run is not retryable" unless workflow_run.may_retry?
        workflow_run.retry!
      end
    end

    def self.fetch_workflow_run_status!(workflow_run)
      Res.new do
        raise "release is not actionable" unless workflow_run.triggering_release.actionable?
        raise "workflow run is not in failed state" unless workflow_run.failed?
        workflow_run.found!
      end
    end

    def self.start_internal_release!(release_platform_run)
      Res.new do
        raise "release is not active" unless release_platform_run.active?
        commit = release_platform_run.release.last_applicable_commit
        Coordinators::CreateInternalRelease.call(release_platform_run, commit)
      end
    end

    def self.start_beta_release!(run)
      Res.new do
        raise "release is not active" unless run.active?
        commit = run.release.last_applicable_commit
        Coordinators::CreateBetaRelease.call(run, commit)
      end
    end

    def self.trigger_submission!(submission)
      Res.new do
        raise "submission is not triggerable" unless submission.triggerable?
        submission.trigger!
      end
    end

    def self.retry_submission!(submission)
      Res.new do
        raise "submission is not actionable" unless submission.actionable?
        raise "submission is not retryable" unless submission.retryable?
        submission.retry!
      end
    end

    def self.start_new_production_release!(release_platform_run, build_id)
      Res.new do
        raise "release is not active" unless release_platform_run.active?
        Coordinators::StartProductionRelease.call(release_platform_run, build_id)
      end
    end

    def self.update_production_build!(submission, build_id)
      Res.new { Coordinators::UpdateBuildOnProduction.call(submission, build_id) }
    end

    def self.prepare_production_submission!(submission)
      Res.new do
        raise "production release is not editable" unless submission.editable?
        submission.start_prepare!
        submission.notify!("Production submission started", :production_submission_started, submission.notification_params)
      end
    end

    def self.start_production_review!(submission)
      Res.new do
        raise "production release is not editable" unless submission.editable?
        submission.start_submission!
      end
    end

    def self.cancel_production_review!(submission)
      Res.new do
        raise "production release is not editable" unless submission.editable?
        submission.start_cancellation!
        submission.notify!("Production submission cancelled", :production_submission_cancelled, submission.notification_params)
      end
    end

    def self.stop_release!(release)
      Res.new { Coordinators::StopRelease.call(release) }
    end

    def self.fully_release_the_previous_rollout!(current_submission)
      return Res.new { raise "release is not actionable" } unless current_submission.release_platform_run.on_track?
      return Res.new { raise "submission has already started" } unless current_submission.created?
      previous_rollout = current_submission.fully_release_previous_production_rollout!
      return Res.new { raise "no previous rollout to complete" } if previous_rollout.nil?
      return Res.new { raise previous_rollout.errors.full_messages.to_sentence } if previous_rollout.errors?
      Res.new { true }
    end

    def self.start_the_store_rollout!(rollout)
      return Res.new { raise "release is not actionable" } unless rollout.actionable?
      return Res.new { raise "rollout has already started" } unless rollout.created?
      rollout.start_release!
      return Res.new { raise rollout.errors.full_messages.to_sentence } if rollout.errors?
      Res.new { true }
    end

    def self.increase_the_store_rollout!(rollout)
      return Res.new { raise "release is not actionable" } unless rollout.actionable?
      return Res.new { raise "rollout is not started" } unless rollout.started?
      rollout.move_to_next_stage!
      return Res.new { raise rollout.errors.full_messages.to_sentence } if rollout.errors?
      Res.new { true }
    end

    def self.pause_the_store_rollout!(rollout)
      return Res.new { raise "release is not actionable" } unless rollout.actionable?
      return Res.new { raise "rollout is not started" } unless rollout.started?
      rollout.pause_release!
      return Res.new { raise rollout.errors.full_messages.to_sentence } if rollout.errors?
      Res.new { true }
    end

    def self.resume_the_store_rollout!(rollout)
      return Res.new { raise "release is not actionable" } unless rollout.actionable?
      return Res.new { raise "rollout is not halted or paused" } unless rollout.halted? || rollout.paused?
      rollout.resume_release!
      return Res.new { raise rollout.errors.full_messages.to_sentence } if rollout.errors?
      Res.new { true }
    end

    def self.halt_the_store_rollout!(rollout)
      return Res.new { raise "release is not actionable" } unless rollout.actionable?
      return Res.new { raise "rollout is not started" } unless rollout.started?
      rollout.halt_release!
      return Res.new { raise rollout.errors.full_messages.to_sentence } if rollout.errors?
      Res.new { true }
    end

    def self.fully_release_the_store_rollout!(rollout)
      return Res.new { raise "release is not actionable" } unless rollout.actionable?
      return Res.new { raise "rollout is not started" } unless rollout.started?
      rollout.release_fully!
      return Res.new { raise rollout.errors.full_messages.to_sentence } if rollout.errors?
      Res.new { true }
    end

    def self.complete_release!(release)
      Res.new do
        release.with_lock do
          raise "release is not ready to be finalized" unless Release::FINALIZE_STATES.include?(release.status)
          raise "release is not ready to be finalized" unless release.ready_to_be_finalized?
          release.start_post_release_phase!
        end

        V2::FinalizeReleaseJob.perform_later(release.id, true)
      end
    end

    def self.mark_release_as_finished!(release)
      Res.new do
        release.with_lock do
          raise "release is not partially finished" unless release.partially_finished?
          release.release_platform_runs.pending_release.map(&:stop!)
          release.start_post_release_phase!
        end

        V2::FinalizeReleaseJob.perform_later(release.id)
      end
    end
  end
end
