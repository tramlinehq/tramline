class ScheduleTrainReleasesJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform
    Train.active.filter(&:automatic?).each do |train|
      train.schedule_release if train.runnable?
    end
  end
end
