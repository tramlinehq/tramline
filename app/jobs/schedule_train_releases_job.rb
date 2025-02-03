class ScheduleTrainReleasesJob < ApplicationJob
  queue_as :high

  def perform
    Train
      .active
      .filter(&:automatic?)
      .filter(&:runnable?)
      .each(&:schedule_release!)
  end
end
