class EventTimeline::EventMessageComponent < ViewComponent::Base
  include AssetsHelper
  include ApplicationHelper

  STAMPABLE_ICONS = {
    StoreSubmission => "truck_delivery",
    Commit => "git_commit",
    PreProdRelease => "box",
    ProductionRelease => "box",
    ReleasePlatformRun => "bolt",
    Release => "bolt",
    WorkflowRun => "workflow",
    Build => "drill"
  }

  BADGE = {
    success: "bg-emerald-100",
    error: "bg-rose-100",
    notice: "bg-amber-100"
  }.with_indifferent_access

  def initialize(passport:)
    @passport = passport
  end

  attr_reader :passport

  def passport_badge(passport)
    BADGE[passport.kind]
  end

  def passport_icon(passport)
    STAMPABLE_ICONS.fetch(passport.stampable_type.constantize, "aerial_lift")
  end

  def author_avatar(name)
    user_avatar(name, limit: 2, size: 36, colors: 90)
  end
end
