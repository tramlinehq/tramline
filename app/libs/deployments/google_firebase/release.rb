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
        :release_metadata,
        :google_firebase_integration?,
        to: :run

      def kickoff!
        Deployments::GoogleFirebase::UploadJob.perform_later(run.id)
      end

      def upload!
        return unless google_firebase_integration?

        run.with_lock do
          return if run.uploaded?

          run.build_artifact.with_open do |file|
            result = provider.upload(file)
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

        upload_status = result.value!
        if upload_status[:done]
          Rails.logger.info("upload is done", upload_status)
          if upload_status[:error]
            run.dispatch_fail!(reason: :upload_failed)
          else
            external_release = result.value![:response][:release]
            external_status = result.value![:response][:result]
            run.create_external_release(external_id: external_release[:name],
              name: external_release[:displayVersion],
              build_number: external_release[:buildVersion],
              added_at: external_release[:createTime],
              status: external_status)
            run.upload!
          end
        else
          raise UploadNotComplete
        end
      end

      def start_release!
        return unless google_firebase_integration?

        return run.complete! if deployment_channel == GoogleFirebaseIntegration::EMPTY_CHANNEL[:id].to_s

        result = provider.release(run.external_release.external_id, deployment_channel)

        Rails.logger.info("started release -- ", result.value!)
        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        run.complete!
      end
    end
  end
end
