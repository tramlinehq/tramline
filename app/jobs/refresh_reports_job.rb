class RefreshReportsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)
    train = release.train

    if release.is_v2?
      Queries::ReleaseBreakdown.warm(release.id)
    else
      Queries::ReleaseSummary.warm(release_id)
    end

    if train.product_v2?
      Queries::DevopsReport.warm(train)
    else
      Charts::DevopsReport.warm(train)
    end
  end
end
