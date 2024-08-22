class RefreshReldexJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(train_id)
    train = Train.find(train_id)

    train.releases.finished.each do |release|
      if release.is_v2?
        Queries::ReleaseBreakdown.warm(release.id, [:reldex])
      else
        Queries::ReleaseSummary.warm(release.id)
      end
    end

    if train.product_v2?
      Queries::DevopsReport.warm(train)
    else
      Charts::DevopsReport.warm(train)
    end
  end
end
