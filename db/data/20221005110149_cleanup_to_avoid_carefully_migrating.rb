class CleanupToAvoidCarefullyMigrating < ActiveRecord::Migration[7.0]
  # there are no active users at this point so this is safe
  def up
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
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
