namespace :db do
  desc "Nuke everything except users, organizations and apps"
  task nuke: [:destructive, :environment] do
    Releases::CommitListener.delete_all
    BuildArtifact.delete_all
    DeploymentRun.delete_all
    Deployment.delete_all
    Releases::Step::Run.delete_all
    Releases::Commit.delete_all
    Releases::Step::Run.delete_all
    Releases::Step.delete_all
    Releases::Train::Run.delete_all
    Releases::Train.delete_all

    puts "Data was nuked!"
  end

  desc "Nuke the train and its entire tree"
  task :nuke_train, %i[train_id] => [:destructive, :environment] do |_, args|
    train_id = args[:train_id].to_s
    train = Releases::Train.find_by(id: train_id)
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
    app.integrations.delete_all
    app.trains.each do |train|
      nuke_train(train)
    end
    app.delete
  end

  def nuke_train(train)
    train.commit_listeners.delete_all
    train.runs.each do |run|
      run.step_runs.each do |srun|
        srun.deployment_runs.each do |drun|
          drun.staged_rollout&.delete
          drun.external_release&.delete
        end
        srun.deployment_runs&.delete_all
        srun.build_artifact&.delete
      end
      run.step_runs&.delete_all
      run.release_metadata&.delete
      run.pull_requests&.delete_all
      run.commits&.delete_all
    end
    train.runs&.delete_all
    train.steps.each do |step|
      step.deployments.delete_all
    end
    train.steps&.delete_all
    train.delete
  end
end
