module Deployments
  module GoogleFirebase
    class Release
      include Loggable

      UploadNotComplete = Class.new(StandardError)

      def self.kickoff!(deployment_run)
        new(deployment_run).kickoff!
      end

      def self.upload!(deployment_run)
        new(deployment_run).upload!
      end

      def self.update_upload_status!(deployment_run, op_name)
        new(deployment_run).update_upload_status!(op_name)
      end

      def self.update_build_notes!(deployment_run, release_id)
        new(deployment_run).update_build_notes!(release_id)
      end

      def self.start_release!(deployment_run)
        new(deployment_run).start_release!
      end

      def initialize(deployment_run)
        @deployment_run = deployment_run
      end

      attr_reader :deployment_run
      alias_method :run, :deployment_run
      delegate :provider,
        :deployment_channel,
        :build_number,
        :release_version,
        :google_firebase_integration?,
        :release_platform,
        :step_run,
        :deployment_notes,
        to: :run
      delegate :platform, to: :release_platform

      def kickoff!
        if (similar_run = step_run.similar_deployment_runs_for(run).find(&:has_uploaded?))
          run.create_external_release(similar_run.external_release.attributes.except("id", "created_at", "updated_at"))
          return run.upload!
        end
        Deployments::GoogleFirebase::UploadJob.perform_later(run.id)
      end

      def upload!
        return unless google_firebase_integration?

        run.with_lock do
          return if run.uploaded?

          run.build_artifact.with_open do |file|
            result = provider.upload(file, run.build_artifact.file.filename.to_s, platform:)
            if result.ok?
              run.start_upload!(op_name: result.value!)
            else
              run.fail_with_error(result.error)
            end
          end
        end
      end

      def update_upload_status!(op_name)
        return unless google_firebase_integration?

        result = provider.get_upload_status(op_name)
        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        op_info = result.value!
        raise UploadNotComplete unless op_info.done?

        release_info = op_info.release
        run.create_external_release(external_id: release_info.id,
          name: release_info.name,
          build_number: release_info.build_number,
          added_at: release_info.added_at,
          status: op_info.status,
          external_link: release_info.console_link)
        run.upload!
        Deployments::GoogleFirebase::UpdateBuildNotesJob.perform_later(run.id, release_info.id)
      end

      def update_build_notes!(release_id)
        provider.update_release_notes(release_id, deployment_notes)
      end

      def start_release!
        return unless google_firebase_integration?

        return run.complete! if deployment_channel == GoogleFirebaseIntegration::EMPTY_CHANNEL[:id].to_s

        result = provider.release(run.external_release.external_id, [deployment_channel])

        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        run.complete!
      end
    end
  end
end
