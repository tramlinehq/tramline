module StepsHelper
  def show_ci_cd(step)
    "#{step.app.ci_cd_provider.display} • #{step.ci_cd_channel["name"]}"
  end

  def platform_subtitle(app, step)
    "For the #{step.release_platform.display_attr(:platform)} platform" if app.cross_platform?
  end

  def auto_deploy_status_badge(step)
    step.auto_deploy? ? "" : "Manual Distribution"
  end

  def auto_deploy_status(step)
    step.auto_deploy? ? "ON" : "OFF"
  end

  def build_artifact_pattern_text(step)
    return unless step.has_uploadables?
    if step.build_artifact_name_pattern.present?
      "picks up build with the pattern <code>#{step.build_artifact_name_pattern}</code> from the above workflow"
    else
      "picks up the largest build from the above workflow"
    end
  end
end
