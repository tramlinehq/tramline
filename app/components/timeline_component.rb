# frozen_string_literal: true

class TimelineComponent < ViewComponent::Base
  include ApplicationHelper

  EVENT_TYPE = {
    success: "bg-green-600 border-green-100 dark:border-green-700 dark:bg-green-500",
    error: "bg-red-600 border-red-100 dark:border-red-700 dark:bg-red-500",
    neutral: "bg-gray-200 border-white dark:border-gray-900 dark:bg-gray-700"
  }

  def initialize(events:)
    @events = events
  end

  attr_reader :events

  def event_color(event)
    EVENT_TYPE.fetch(event[:type] || :neutral)
  end
end
