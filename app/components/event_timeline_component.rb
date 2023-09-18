class EventTimelineComponent < ViewComponent::Base
  include ApplicationHelper

  STAMPABLE_ICONS = {
    DeploymentRun => "truck_delivery",
    Commit => "git_commit",
    StepRun => "box",
    ReleasePlatformRun => "bolt",
    Release => "bolt"
  }

  def initialize(events:)
    @events = events
  end

  def events_by_days
    @events.group_by { |e| e.event_timestamp.strftime("%a #{e.event_timestamp.day.ordinalize} %B, %Y") }
  end

  def justify_grid(passport)
    return "justify-self-center" if cross_platform?(passport)
    return "justify-self-start" if android?(passport)
    "justify-self-end" if ios?(passport)
  end

  def justify_content(passport)
    return "justify-self-center" if cross_platform?(passport)
    "justify-self-end" if android?(passport)
  end

  def connector(passport, direction)
    if direction == :left && ios?(passport)
      content_tag(:div, "", class: "border-gray-200 w-10 border-t-3 mr-1")
    elsif direction == :right && android?(passport)
      content_tag(:div, "", class: "border-gray-200 w-10 border-b-3 ml-1")
    end
  end

  def passport_icon(passport)
    STAMPABLE_ICONS.fetch(passport.stampable_type.constantize, "aerial_lift")
  end

  def author_avatar(name)
    user_avatar(name, limit: 2, size: 42, colors: 90)
  end

  def cross_platform?(passport) = passport.platform == "cross_platform"

  def android?(passport) = passport.platform == "android"

  def ios?(passport) = passport.platform == "ios"
end
