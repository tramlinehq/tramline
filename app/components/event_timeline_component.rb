class EventTimelineComponent < ViewComponent::Base
  include ApplicationHelper
  include AssetsHelper

  STAMPABLE_ICONS = {
    DeploymentRun => "truck_delivery",
    Commit => "git_commit",
    StepRun => "box",
    ReleasePlatformRun => "bolt",
    Release => "bolt"
  }

  BADGE = {
    success: "bg-emerald-100",
    error: "bg-rose-100",
    notice: "bg-amber-100"
  }.with_indifferent_access

  def initialize(events:)
    @events = events
  end

  def events_by_days
    @events.group_by { |e| e.event_timestamp.strftime("%A #{e.event_timestamp.day.ordinalize} %B, %Y") }
  end

  def justify_content(passport)
    return "justify-self-center col-span-2 mb-2" if cross_platform?(passport)
    "justify-self-end" if android?(passport)
  end

  BASE_CONNECTOR_STYLES = "border-gray-200 w-10".freeze

  def connector(passport, direction)
    if direction == :left && ios?(passport)
      content_tag(:div, "", class: BASE_CONNECTOR_STYLES + " border-t-3 mr-1")
    elsif direction == :right && android?(passport)
      content_tag(:div, "", class: BASE_CONNECTOR_STYLES + " border-b-3 ml-1")
    end
  end

  BASE_ACTIVITY_METADATA_STYLES = "text-xs text-gray-400 bg-white p-1".freeze

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

  def passport_icon(passport)
    STAMPABLE_ICONS.fetch(passport.stampable_type.constantize, "aerial_lift")
  end

  def passport_badge(passport)
    BADGE[passport.kind]
  end

  def author_avatar(name)
    user_avatar(name, limit: 2, size: 36, colors: 90)
  end

  def ios?(passport) = passport.platform == "ios"

  def android?(passport) = passport.platform == "android"

  def cross_platform?(passport) = passport.platform == "cross_platform"
end
