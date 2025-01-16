# frozen_string_literal: true

class TimelineComponent < ViewComponent::Base
  include ApplicationHelper

  DEFAULT_TRUNCATE = 3
  EVENT_TYPE = {
    success: "bg-green-500 border-white dark:border-main-900 dark:bg-green-500",
    error: "bg-red-500 border-white dark:border-main-900 dark:bg-red-500",
    neutral: "bg-main-200 border-white dark:border-main-900 dark:bg-main-700",
    notice: "bg-sky-500 border-white dark:border-sky-900 dark:bg-sky-700"
  }

  def initialize(events:, truncate: false, view_all_link: nil)
    raise ArgumentError, "you must supply a 'view all' link when truncate is on" if truncate && view_all_link.nil?

    @events = events
    @truncate = truncate
    @view_all_link = view_all_link
  end

  attr_reader :truncate, :view_all_link

  def event_color(event)
    EVENT_TYPE.fetch(event[:type] || :neutral)
  end

  def events
    if truncate
      @events.take(DEFAULT_TRUNCATE)
    else
      @events
    end
  end
end
