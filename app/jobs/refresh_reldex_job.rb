class RefreshReldexJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(train_id)
    train = Train.find(train_id)

    Charts::DevopsReport.warm(train)
    train.releases.finished.each do |release|
      if release.is_v2?
        Queries::ReleaseBreakdown.warm(release.id, [:reldex])
      else
        Queries::ReleaseSummary.warm(release.id)
      end
    end
  end
end
