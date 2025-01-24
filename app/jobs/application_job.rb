class ApplicationJob
  include Sidekiq::Job
  include Loggable
  include Backoffable

  Signal = Coordinators::Signals
  Action = Coordinators::Actions

  protected

  def logger
    @logger ||= Sidekiq.logger
  end
end
