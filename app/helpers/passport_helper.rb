module PassportHelper
  BADGE = {
    success: "bg-emerald-100",
    error: "bg-rose-100",
    notice: "bg-amber-100",
  }.with_indifferent_access

  ICON = {
    "DeploymentRun" => "truck_delivery",
    "Releases::Commit" => "git_commit",
    "Releases::Step::Run" => "box",
    "Releases::Train::Run" => "bolt"
  }

  def passport_badge(passport)
    BADGE[passport.kind]
  end

  def passport_icon(passport)
    ICON.fetch(passport.stampable_type, "aerial_lift")
  end
end
