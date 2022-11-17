module StepsHelper
  def show_ci_cd_provider(step)
    step.app.ci_cd_provider.display
  end

  def show_ci_cd_channel(step)
    step.ci_cd_channel.values.first
  end
end
