class RefreshReportsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)
    train = release.train

    Charts::DevopsReport.warm(train)
    Queries::ReleaseSummary.warm(release_id)
  end
end
