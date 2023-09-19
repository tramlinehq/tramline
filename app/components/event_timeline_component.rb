class EventTimelineComponent < ViewComponent::Base
  include ApplicationHelper
  include AssetsHelper

  def initialize(app:, events:)
    @app = app
    @events = events
  end

  EXCLUSIONS = {
    "DeploymentRun" => ["created"],
    "StepRun" => %w[build_available finished]
  }

  def events_by_days
    @events
      .reject { |e| EXCLUSIONS[e.stampable_type].present? && e.reason.in?(EXCLUSIONS[e.stampable_type]) }
      .group_by { |e| time_format(e.event_timestamp, only_date: true) }
  end

  def justify_content(passport)
    return "justify-self-center col-span-2 mb-2" if cross_platform?(passport)
    return "justify-self-end" if android?(passport)
    "justify-self-start" if ios?(passport)
  end

  BASE_CONNECTOR_STYLES = "border-slate-200 w-10".freeze

  def connector(passport, direction)
    if direction == :left && ios?(passport)
      content_tag(:div, "", class: BASE_CONNECTOR_STYLES + " border-t-3 mr-1")
    elsif direction == :right && android?(passport)
      content_tag(:div, "", class: BASE_CONNECTOR_STYLES + " border-b-3 ml-1")
    end
  end

  BASE_ACTIVITY_METADATA_STYLES = "text-xs text-slate-400 bg-white p-1".freeze

  def activity_metadata(passport, direction)
    justification =
      if direction == :left && ios?(passport)
        " justify-self-end mr-2"
      elsif direction == :right && android?(passport)
        " justify-self-start ml-2"
      elsif direction == :left && cross_platform?(passport)
        " justify-self-center col-span-2 mt-2"
      else
        return
      end

    activity_metadata_content(passport, justification)
  end

  def activity_metadata_content(passport, justification)
    content_tag(:div, class: BASE_ACTIVITY_METADATA_STYLES + justification) do
      concat content_tag(:time, time_format(passport.event_timestamp, only_time: true))
      concat content_tag(:span, " – #{passport.author_name}")
    end
  end

  def hide_timeline?(index)
    index > 0
  end

  def hide_timeline(index)
    "hidden" if hide_timeline?(index)
  end

  def ios?(passport) = passport.platform == "ios"

  def android?(passport) = passport.platform == "android"

  def cross_platform?(passport) = passport.platform == "cross_platform"

  def cross_platform_app? = @app.cross_platform?
end
