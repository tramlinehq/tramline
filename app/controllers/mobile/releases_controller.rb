module Mobile
  class ReleasesController < SignedInApplicationController
    def index
      @apps_with_releases =
        current_organization
          .apps.includes(releases: [:train])
          .where.not(releases: {id: nil})
          .order(:name)
    end

    def show
      @release = current_organization.releases.friendly.find(params[:id])
      @release_presenter = ReleasePresenter.new(@release, view_context)
      @production_rollouts = @release.release_platform_runs.flat_map do |rpr|
        [rpr.inflight_store_rollout, rpr.active_store_rollout].compact
      end
    end
  end
end
