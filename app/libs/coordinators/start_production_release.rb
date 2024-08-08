class Coordinators::StartProductionRelease
  def self.call(release_platform_run, build_id, override: false)
    new(release_platform_run, build_id, override:).call
  end

  def initialize(release_platform_run, build_id, override: false)
    @release_platform_run = release_platform_run
    @build = @release_platform_run.rc_builds.find(build_id)
    @override = override
  end

  delegate :transaction, to: ActiveRecord::Base

  def call
    @release_platform_run.with_lock do
      return unless @release_platform_run.on_track?
      return if previous&.active? && !@override

      if @override
        previous&.mark_as_stale!
      end

      @release_platform_run
        .production_releases
        .create!(build: @build, config:, previous:)
        .trigger_submission!
    end
  end

  private

  def previous
    @release_platform_run.latest_production_release
  end

  def config
    @release_platform_run.conf.production_release.value
  end
end
