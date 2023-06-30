module StepsHelper
  def show_ci_cd(step)
    "#{step.app.ci_cd_provider.display} • #{step.ci_cd_channel["name"]}"
  end

  def platform_subtitle(app, step)
    "For the #{step.release_platform.display_attr(:platform)} platform" if app.cross_platform?
  end
end
