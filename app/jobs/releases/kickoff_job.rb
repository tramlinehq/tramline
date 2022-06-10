require "sidekiq-scheduler"

class Releases::KickoffJob
  include Sidekiq::Worker

  def perform(*_args)
    Releases::Train.active.each do |train|
      TrainJob.perform_now(train.id) if train.runnable?
    end
  end
end
