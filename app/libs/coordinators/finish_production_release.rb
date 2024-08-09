class Coordinators::FinishProductionRelease
  def self.call(release_platform_run)
    new(release_platform_run).call
  end

  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
    @release = release_platform_run.release
    @app = release_platform_run.app
  end

  delegate :transaction, to: ActiveRecord::Base

  def call
    transaction do
      @release_platform_run.finish_v2!
      update_release!
    end

    @app.refresh_external_app
    # TODO: [V2] notify properly
    # train.notify_with_snippet!("Deployment was successful!",
    #                            :deployment_finished,
    #                            notification_params,
    #                            step_run.build_notes,
    #                            "Changes since the last release:")
  end

  def update_release!
    return @release.start_post_release_phase! if @release.ready_to_be_finalized?
    @release.partially_finish!
  end
end
