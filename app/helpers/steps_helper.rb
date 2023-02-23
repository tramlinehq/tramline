module StepsHelper
  def show_ci_cd(step)
    "#{step.app.ci_cd_provider.display} • #{step.ci_cd_channel["name"]}"
  end
end
