module Mobile
  class ReleasesController < SignedInApplicationController
    def index
      @apps_with_releases = current_organization.apps.includes(releases: [:train, :release_pilot])
        .where.not(releases: {id: nil})
        .order(:name)
    end
  end
end
