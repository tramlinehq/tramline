class EventTimelineComponent < ViewComponent::Base
  include ApplicationHelper
  include PassportHelper

  def initialize(events:)
    @events = events
  end

  def events_by_days
    @events.group_by { |e| e.event_timestamp.strftime("%a #{e.event_timestamp.day.ordinalize} %B, %Y") }
  end
end
