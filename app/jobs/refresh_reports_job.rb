class RefreshReportsJob < ApplicationJob
  def perform(release_id)
    release = Release.find(release_id)
    train = release.train
    Queries::ReleaseBreakdown.warm(release.id)
    Queries::DevopsReport.warm(train)
  end
end
