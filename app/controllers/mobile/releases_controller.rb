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
      @app = @release.app
      @release_presenter = ReleasePresenter.new(@release, view_context)
      platform_runs = @release.release_platform_runs
      @inflight_rollouts = platform_runs.filter_map(&:inflight_store_rollout).group_by(&:platform)
      @active_rollouts = platform_runs.filter_map(&:active_store_rollout).group_by(&:platform)
    rescue ActiveRecord::RecordNotFound
      redirect_to mobile_releases_path, alert: t(".not_found")
    end
  end
end
