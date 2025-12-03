class ReleaseListComponent < BaseComponent
  include Memery

  def initialize(train:)
    @train = train
    @ongoing_release = train.ongoing_release
    @hotfix_release = train.hotfix_release
    @upcoming_release = train.upcoming_release
  end

  attr_reader :train, :ongoing_release, :hotfix_release, :upcoming_release
  delegate :app, :hotfix_from, :previous_releases, :last_finished_release, to: :train

  # we don't check for train.releases.none?
  # because the constituent releases that are loaded on the page are already memoized, so we avoid a query
  def no_releases?
    previous_releases.empty? && ongoing_release.nil? && upcoming_release.nil? && hotfix_release.nil? && last_finished_release.nil?
  end

  memoize def devops_report
    DevopsReportPresenter.new(train.devops_report)
  end

  def ios_enabled?
    app.cross_platform? || app.ios?
  end

  def no_release_empty_state
    unless app.ready?
      return {
        title: "App is not ready",
        text: "There are required integrations that need to be configured before you can start creating releases.",
        content: render(ButtonComponent.new(scheme: :light, type: :link, label: "Configure Integration", options: app_integrations_path(app), size: :xxs, authz: false))
      }
    end

    if train.automatic?
      if train.activatable?
        {
          title: "Activate the train",
          text: "Once you've activated, we will automatically start running your scheduled releases."
        }
      else
        {
          title: "Upcoming release",
          text: "Your first scheduled release will automatically kick-off at #{train.kickoff_at.to_fs(:short)}. You can also manually run a new release by clicking the prepare button."
        }
      end
    else
      platform = train.release_platforms.first.platform
      text = "You can now start creating new releases. We have added some default submissions settings for you. This involves picking the right workflows and configuring the right channels for build distribution. Please review these before starting a release."
      button_link = edit_app_train_platform_submission_config_path(app, train, platform)
      {
        title: "Create your very first release",
        text:,
        content: render(ButtonComponent.new(scheme: :light, type: :link, label: "Review submission settings", options: button_link, size: :xxs, authz: false))
      }
    end
  end
end
