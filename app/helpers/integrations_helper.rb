module IntegrationsHelper
  SHOW_CATEGORY_LIST =
    {version_control: "version control", ci_cd: "continuous integration", notification: "notifications", build_channel: "deployments"}.freeze

  def show_category(category)
    SHOW_CATEGORY_LIST.with_indifferent_access[category].titleize
  end
end
