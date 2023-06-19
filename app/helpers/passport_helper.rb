module PassportHelper
  BADGE = {
    success: "bg-emerald-100",
    error: "bg-rose-100",
    notice: "bg-amber-100"
  }.with_indifferent_access

  STAMPABLE_ICONS = {
    DeploymentRun => "truck_delivery",
    Commit => "git_commit",
    StepRun => "box",
    ReleasePlatformRun => "bolt",
    Release => "bolt"
  }

  def passport_badge(passport)
    BADGE[passport.kind]
  end

  def passport_icon(passport)
    STAMPABLE_ICONS.fetch(passport.stampable_type.constantize, "aerial_lift")
  end
end
