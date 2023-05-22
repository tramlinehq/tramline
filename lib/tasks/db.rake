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

    puts "Train successfully deleted!"
  end
end
