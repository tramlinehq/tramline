class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError
  sidekiq_options retry: 0
  Signal = Coordinators::Signals

  protected

  def logger
    @logger ||= Sidekiq.logger
  end
end
