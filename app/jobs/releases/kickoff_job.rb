require "sidekiq-scheduler"

class Releases::KickoffJob
  include Sidekiq::Worker

  def perform(*args)
    Releases::Train.active.each do |train|
      TrainJob.perform_now(train.id)
    end
  end
end
