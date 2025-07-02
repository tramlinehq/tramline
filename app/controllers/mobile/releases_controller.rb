module Mobile
  class ReleasesController < SignedInApplicationController
    def index
      @apps_with_releases = current_organization.apps.includes(releases: [:train, :release_pilot])
        .where.not(releases: {id: nil})
        .order(:name)
    end

    def show
      @release = Release.find(params[:id])
      @release_presenter = ReleasePresenter.new(@release, self)
    end
  end
end
