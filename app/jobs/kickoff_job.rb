require "sidekiq-scheduler"

class KickoffJob
  include Sidekiq::Worker

  def perform(*args)
    puts "running scheduler"
  end
end
