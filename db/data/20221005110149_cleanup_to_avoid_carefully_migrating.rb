class CleanupToAvoidCarefullyMigrating < ActiveRecord::Migration[7.0]
  def up
    return

    # there are no active users at this point so this is safe
    ActiveRecord::Base.transaction do
      Releases::CommitListener.delete_all if defined?(Releases::CommitListener)
      BuildArtifact.delete_all if defined?(BuildArtifact)
      Releases::Step::Run.delete_all if defined?(Releases::Step::Run)
      SignOff.delete_all if defined?(SignOff)
      Releases::Commit.delete_all if defined?(Releases::Commit)
      Releases::Step::Run.delete_all if defined?(Releases::Step::Run)
      Releases::Step.delete_all if defined?(Releases::Step)
      Releases::Train::Run.delete_all if defined?(Releases::Train::Run)
      TrainSignOffGroup.delete_all if defined?(TrainSignOffGroup)
      Releases::Train.delete_all if defined?(Releases::Train)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
