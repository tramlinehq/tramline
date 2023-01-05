module Notifiers
  module Slack
    class Builder
      RENDERERS = {
        build_finished: Renderers::BuildFinished,
        deployment_finished: Renderers::DeploymentFinished,
        release_ended: Renderers::ReleaseEnded,
        step_failed: Renderers::StepFailed,
        release_started: Renderers::ReleaseStarted
      }

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
