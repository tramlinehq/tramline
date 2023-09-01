namespace :db do
  desc "Merge an android app and ios app into one"
  task :merge_apps, [:ios_app_slug, :android_app_slug] => [:destructive, :environment] do |_, args|
    ios_app_slug = args[:ios_app_slug].to_s
    android_app_slug = args[:android_app_slug].to_s

    ios_app = App.find_by slug: ios_app_slug
    abort "iOS app not found" unless ios_app&.ios?

    android_app = App.find_by slug: android_app_slug
    abort "Android app not found" unless android_app&.android?

    abort "Can't merge, active release happening for the apps" if ios_app.active_runs.exists? || android_app.active_runs.exists?
    abort "Appp bundle identifiers are not the same" unless ios_app.bundle_identifier == android_app.bundle_identifier
    abort "App timezones are not the same" unless ios_app.timezone == android_app.timezone
    abort "VCS integrations are not the same" unless ios_app.vcs_provider.instance_of?(android_app.vcs_provider.class)
    abort "CI/CD integrations are not the same" unless ios_app.ci_cd_provider.instance_of?(android_app.ci_cd_provider.class)
    abort "Code repositories are not the same" unless ios_app.config.code_repository == android_app.config.code_repository

    puts "Merging #{ios_app_slug} and #{android_app_slug} apps"

    ActiveRecord::Base.transaction do
      x_plat_app = App.create!(bundle_identifier: ios_app.bundle_identifier,
        name: ios_app.name + " Cross Platform",
        description: ios_app.description,
        platform: App.platforms[:cross_platform],
        build_number: [ios_app.build_number, android_app.build_number].max,
        timezone: ios_app.timezone,
        organization: ios_app.organization)

      ios_config = ios_app.config
      android_config = android_app.config
      x_plat_app.config.update!(code_repository: ios_config.code_repository,
        notification_channel: ios_config.notification_channel || android_config.notification_channel,
        bitrise_project_id: ios_config.bitrise_project_id || android_config.bitrise_project_id,
        firebase_ios_config: ios_config.firebase_ios_config,
        firebase_android_config: android_config.firebase_android_config)

      new_vcs_provider = ios_app.vcs_provider.dup
      new_vcs_provider.save!
      new_vcs_integration = ios_app.vcs_provider.integration.dup
      new_vcs_integration.app = x_plat_app
      new_vcs_integration.providable = new_vcs_provider
      new_vcs_integration.save!

      new_ci_cd_provider = ios_app.ci_cd_provider.dup
      new_ci_cd_provider.save!
      new_ci_cd_integration = ios_app.ci_cd_provider.integration.dup
      new_ci_cd_integration.app = x_plat_app
      new_ci_cd_integration.providable = new_ci_cd_provider
      new_ci_cd_integration.save!

      notif_provider = ios_app.notification_provider || android_app.notification_provider
      if notif_provider
        new_notification_provider = notif_provider.dup
        new_notification_provider.save!
        new_notification_integration = notif_provider.integration.dup
        new_notification_integration.app = x_plat_app
        new_notification_integration.providable = new_notification_provider
        new_notification_integration.save!
      end

      build_channel_integrations = ios_app.integrations.build_channel + android_app.integrations.build_channel

      AppStoreIntegration.skip_callback(:create, :before, :set_external_details_on_app)
      GooglePlayStoreIntegration.skip_callback(:commit, :after, :refresh_external_app)
      AppStoreIntegration.skip_callback(:commit, :after, :refresh_external_app)
      build_channel_integrations.uniq { |x| x.providable_type }.each do |bi|
        new_build_channel_provider = bi.providable.dup
        new_build_channel_provider.save(validate: false)
        new_build_channel_integration = bi.dup
        new_build_channel_integration.app = x_plat_app
        new_build_channel_integration.providable = new_build_channel_provider
        new_build_channel_integration.save!
      end

      abort "Too many trains" if ios_app.trains.size > 1 || android_app.trains.size > 1
      abort "Not enough trains" if ios_app.trains.size < 1 || android_app.trains.size < 1

      ios_train = ios_app.trains.first
      android_train = android_app.trains.first

      abort "Different branching strategies" if ios_train.branching_strategy != android_train.branching_strategy
      using RefinedString

      Train.skip_callback(:create, :before, :set_current_version)
      Train.skip_callback(:create, :before, :set_default_status)
      Train.skip_callback(:create, :after, :create_release_platforms)
      Train.skip_callback(:update, :after, :schedule_release!)

      new_train = ios_train.dup
      new_train.app = x_plat_app
      new_train.version_current = [ios_train.version_current, android_train.version_current].map(&:to_semverish).max.to_s
      new_train.save!

      [ios_train, android_train].each do |train|
        existing_release_platform = train.release_platforms.first
        release_platform = existing_release_platform.dup
        release_platform.train = new_train
        release_platform.app = x_plat_app
        release_platform.save!

        existing_release_platform&.steps&.each do |step|
          new_step = step.dup
          new_step.release_platform = release_platform

          step.deployments.each do |deployment|
            new_deployment = deployment.dup
            new_deployment.integration = x_plat_app
              .integrations
              .find_by(category: deployment.integration.category,
                providable_type: deployment.integration.providable_type)
            new_step.deployments << new_deployment
          end

          new_step.save!
        end
      end
    end
  end

  desc "Nuke everything except users, organizations and apps"
  task nuke: [:destructive, :environment] do
    CommitListener.delete_all
    BuildArtifact.delete_all
    DeploymentRun.delete_all
    Deployment.delete_all
    StepRun.delete_all
    Commit.delete_all
    StepRun.delete_all
    Step.delete_all
    ReleasePlatformRun.delete_all
    ReleasePlatform.delete_all
    Release.delete_all
    Train.delete_all

    puts "Data was nuked!"
  end

  desc "Nuke the train and its entire tree"
  task :nuke_train, %i[train_id] => [:destructive, :environment] do |_, args|
    train_id = args[:train_id].to_s
    train = Train.find_by(id: train_id)
    abort "Train not found!" unless train

    ActiveRecord::Base.transaction do
      nuke_train(train)
    end

    puts "Train successfully deleted!"
  end

  desc "Nuke the app and its entire tree"
  task :nuke_app, %i[app_slug] => [:destructive, :environment] do |_, args|
    app_slug = args[:app_slug].to_s
    app = App.find_by slug: app_slug
    abort "App not found!" unless app

    ActiveRecord::Base.transaction do
      nuke_app(app)
    end

    puts "App successfully deleted!"
  end

  def nuke_app(app)
    app.config.delete
    app.external_apps.delete_all
    app.integrations.delete_all
    app.trains.each do |train|
      nuke_train(train)
    end
    app.delete
  end

  def nuke_train(train)
    train.releases.each do |run|
      run.release_platform_runs.each do |prun|
        prun.step_runs.each do |srun|
          srun.deployment_runs.each do |drun|
            drun.staged_rollout&.delete
            drun.external_release&.delete
          end
          srun.deployment_runs&.delete_all
          srun.build_artifact&.delete
        end
        prun.step_runs&.delete_all
      end
      run.all_commits&.delete_all
      run.release_metadata&.delete
      run.release_changelog&.delete
      run.pull_requests&.delete_all
      run.release_platform_runs&.delete_all
    end
    train.releases&.delete_all
    train.scheduled_releases&.delete_all
    train.release_platforms.each do |release_platform|
      train.steps.each do |step|
        step.deployments.delete_all
      end
      release_platform.steps&.delete_all
      sql = "delete from commit_listeners where release_platform_id = '#{release_platform.id}'"
      ActiveRecord::Base.connection.execute(sql)
    end
    train.release_platforms&.delete_all
    train.delete
  end
end
