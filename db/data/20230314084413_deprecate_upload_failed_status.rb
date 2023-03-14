class DeprecateUploadFailedStatus < ActiveRecord::Migration[7.0]
  def up
    DeploymentRun.upload_failed.each do |run|
      run.update(failure_reason: :unknown_failure, status: :failed)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
