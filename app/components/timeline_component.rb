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

  def time_style(dark: false)
    style = "text-gray-400"
    style += " dark:text-gray-500" if dark
    style
  end

  def title_style(dark: false)
    style = "text-gray-900"
    style += " dark:text-white" if dark
    style
  end

  def description_style(dark: false)
    style = "text-gray-500"
    style += " dark:text-gray-400" if dark
    style
  end

  def border_style(dark: false)
    style = "border-gray-200"
    style += " dark:border-gray-700" if dark
    style
  end
end
