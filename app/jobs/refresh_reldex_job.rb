class RefreshReldexJob < ApplicationJob
  def perform(train_id)
    train = Train.find(train_id)

    train.releases.finished.each do |release|
      Queries::ReleaseBreakdown.warm(release.id, [:reldex])
    end

    Queries::DevopsReport.warm(train)
  end
end
