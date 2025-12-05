# frozen_string_literal: true

class OutgoingWebhookEventsComponent < BaseComponent
  include Memery

  def initialize(events, view_all_link: nil)
    @events = events
    @view_all_link = view_all_link
  end

  attr_reader :dom_id, :view_all_link

  memoize def events
    @events.map do |event|
      type =
        case event.status
        when "failed" then :error
        when "success" then :success
        else :pending
        end

      {
        type:,
        title: event.event_type,
        description: "Message ID: #{event.response_data["id"]}",
        timestamp: time_format(event.event_timestamp, with_year: false)
      }
    end
  end
end
