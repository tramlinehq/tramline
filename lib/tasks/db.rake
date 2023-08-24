namespace :db do
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
