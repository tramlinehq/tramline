module Notifiers
  module Slack
    class Builder
      # there are individual classes for each message so that any state, if necessary, can be encapsulated
      # think of them as view components
      RENDERERS = {
        deployment_finished: Renderers::DeploymentFinished,
        release_ended: Renderers::ReleaseEnded,
        release_stopped: Renderers::ReleaseStopped,
        release_started: Renderers::ReleaseStarted,
        step_started: Renderers::StepStarted,
        step_failed: Renderers::StepFailed,
        build_available: Renderers::BuildAvailable,
        submit_for_review: Renderers::SubmitForReview,
        review_approved: Renderers::ReviewApproved,
        review_failed: Renderers::ReviewFailed,
        staged_rollout_updated: Renderers::StagedRolloutUpdated,
        release_scheduled: Renderers::ReleaseScheduled,
        backmerge_failed: Renderers::BackmergeFailed,
        staged_rollout_paused: Renderers::StagedRolloutPaused,
        staged_rollout_resumed: Renderers::StagedRolloutResumed,
        staged_rollout_halted: Renderers::StagedRolloutHalted,
        staged_rollout_completed: Renderers::StagedRolloutCompleted,
        staged_rollout_fully_released: Renderers::StagedRolloutFullyReleased,
        deployment_failed: Renderers::DeploymentFailed,
        release_health_events: Renderers::ReleaseHealthEvents,
        build_available_v2: Renderers::BuildAvailableV2,
        internal_release_finished: Renderers::InternalReleaseFinished,
        internal_release_failed: Renderers::InternalReleaseFailed,
        beta_submission_finished: Renderers::BetaSubmissionFinished,
        submission_failed: Renderers::SubmissionFailed,
        production_submission_started: Renderers::ProductionSubmissionStarted,
        production_submission_in_review: Renderers::ProductionSubmissionInReview,
        production_submission_approved: Renderers::ProductionSubmissionApproved,
        production_submission_rejected: Renderers::ProductionSubmissionRejected,
        production_submission_cancelled: Renderers::ProductionSubmissionCancelled,
        production_rollout_started: Renderers::ProductionRolloutStarted,
        production_rollout_paused: Renderers::ProductionRolloutPaused,
        production_rollout_resumed: Renderers::ProductionRolloutResumed,
        production_rollout_halted: Renderers::ProductionRolloutHalted,
        production_rollout_updated: Renderers::ProductionRolloutUpdated,
        production_release_finished: Renderers::ProductionReleaseFinished,
        workflow_run_failed: Renderers::WorkflowRunFailed,
        workflow_run_halted: Renderers::WorkflowRunHalted,
        workflow_run_unavailable: Renderers::WorkflowRunUnavailable
      }.with_indifferent_access

      MissingSlackRenderer = Class.new(StandardError)

      unless Set.new(RENDERERS.keys).eql?(Set.new(NotificationSetting.kinds.keys))
        raise MissingSlackRenderer
      end

      class RendererNotFound < ArgumentError; end

      def self.build(type, **params)
        new(type, **params).build
      end

      def initialize(type, **params)
        @type = type
        @params = params
      end

      def build
        raise RendererNotFound unless RENDERERS.key?(type)
        RENDERERS[type].render_json(**params)
      end

      private

      attr_reader :type, :params
    end
  end
end
