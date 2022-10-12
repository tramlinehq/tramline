namespace :db do
  desc "Nuke everything except users, organizations and apps"
  task nuke: [:destructive, :environment] do
    Releases::CommitListener.delete_all
    ReleaseSituation.delete_all
    BuildArtifact.delete_all
    Releases::Step::Run.delete_all
    SignOff.delete_all
    Releases::Commit.delete_all
    Releases::Step::Run.delete_all
    Releases::Step.delete_all
    Releases::Train::Run.delete_all
    TrainSignOffGroup.delete_all
    Releases::Train.delete_all

    puts "Data was nuked!"
  end
end
