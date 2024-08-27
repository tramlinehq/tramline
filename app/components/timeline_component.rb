# frozen_string_literal: true

class TimelineComponent < ViewComponent::Base
  include ApplicationHelper

  EVENT_TYPE = {
    success: "bg-green-500 border-white dark:border-main-900 dark:bg-green-500",
    error: "bg-red-500 border-white dark:border-main-900 dark:bg-red-500",
    neutral: "bg-main-200 border-white dark:border-main-900 dark:bg-main-700",
    notice: "bg-indigo-500 border-white dark:border-indigo-900 dark:bg-indigo-700"
  }

  def initialize(events:)
    @events = events
  end

  attr_reader :events

  def event_color(event)
    EVENT_TYPE.fetch(event[:type] || :neutral)
  end
end
