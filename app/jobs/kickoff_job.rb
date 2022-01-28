require "sidekiq-scheduler"

class KickoffJob
  include Sidekiq::Worker

  def perform(*args)
    Releases::Train.active.each do |train|
      if train.runnable?
        KickoffTrainJob.perform_now(train.id)
      end
    end
  end
end
