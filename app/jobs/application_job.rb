class ApplicationJob
  include Sidekiq::Job

  Signal = Coordinators::Signals
  Action = Coordinators::Actions

  protected

  def logger
    @logger ||= Sidekiq.logger
  end
end
