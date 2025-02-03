class ApplicationJob
  include Sidekiq::Job
  include Loggable
  include Backoffable

  sidekiq_options retry: 0

  Signal = Coordinators::Signals
  Action = Coordinators::Actions

  protected

  def logger
    @logger ||= Sidekiq.logger
  end
end
