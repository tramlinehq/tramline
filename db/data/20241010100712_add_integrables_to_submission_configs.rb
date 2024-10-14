# frozen_string_literal: true

class AddIntegrablesToSubmissionConfigs < ActiveRecord::Migration[7.2]
  def up
    Config::Submission.find_each do |submission|
      app = submission.release_step_config.release_platform_config.release_platform.app
      submission.integrable = app
      submission.save!
    end

    StoreSubmission.find_each do |submission|
      app = submission.release_platform_run.app
      submission.update! config: submission.config.merge(integrable_id: app.id, integrable_type: "App")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
