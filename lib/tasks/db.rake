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
end

def nuke_train(train)
  train.releases.each do |run|
    run.release_platform_runs.each do |prun|
      prun.step_runs.each do |srun|
        srun.deployment_runs.each do |drun|
          drun.staged_rollout&.delete
          drun.staged_rollout&.passports&.delete_all
          drun.external_release&.delete
          drun.release_health_metrics&.delete_all
          drun.passports&.delete_all
        end
        srun.deployment_runs&.delete_all
        srun.build_artifact&.delete
        srun.passports&.delete_all
        srun.external_build&.delete
      end
      prun.step_runs&.delete_all
      prun.passports&.delete_all
      prun.release_metadata&.delete_all
    end
    run.pull_requests&.delete_all
    run.release_platform_runs&.delete_all
    run.all_commits.each do |commit|
      commit.passports&.delete_all
    end
    run.all_commits&.delete_all
    run.release_changelog&.delete
    run.build_queues&.delete_all
    run.passports&.delete_all
  end
  train.releases&.delete_all
  train.scheduled_releases&.delete_all
  train.release_index&.components&.delete_all
  train.release_index&.delete
  train.release_platforms.each do |release_platform|
    release_platform.all_steps.each do |step|
      step.all_deployments.delete_all
    end
    release_platform.all_steps&.delete_all
    sql = "delete from commit_listeners where release_platform_id = '#{release_platform.id}'"
    ActiveRecord::Base.connection.execute(sql)
  end
  train.release_platforms&.delete_all
  train.notification_settings&.delete_all
  train.delete
end
