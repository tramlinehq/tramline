class Coordinators::SoakPeriodCompletionJob < ApplicationJob
  sidekiq_options retry: 3, queue: :default

  def perform(release_id)
    release = Release.find(release_id)
    release.with_lock do
      return unless release.soak_period_completed?
      release.event_stamp!(reason: :soak_period_completed, kind: :notice)
      Coordinators::Signals.continue_after_soak_period!(release)
    end
  end
end
