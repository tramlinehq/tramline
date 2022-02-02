require "sidekiq-scheduler"

class Releases::KickoffJob
  include Sidekiq::Worker

  def perform(*args)
    Releases::Train.active.each do |train|
      if train.runnable?
        TrainJob.perform_now(train.id)
      end
    end
  end
end
