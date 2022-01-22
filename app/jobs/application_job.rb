class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError

  protected

  def logger
    @logger ||= Sidekiq.logger
  end
end
