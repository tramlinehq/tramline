class RefreshTrainReportsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(train_id)
    train = Train.find(train_id)

    Charts::DevopsReport.warm(train)
    train.releases.finished.each do |release|
      Queries::ReleaseSummary.warm(release.id)
    end
  end
end
