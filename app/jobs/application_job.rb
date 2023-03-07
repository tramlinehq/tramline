class ApplicationJob < ActiveJob::Base
  include Backoffable
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError
  sidekiq_options retry: 0

  def logger
    @logger ||= Sidekiq.logger
  end
end
