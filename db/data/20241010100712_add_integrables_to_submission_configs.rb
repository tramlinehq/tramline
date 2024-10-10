# frozen_string_literal: true

class AddIntegrablesToSubmissionConfigs < ActiveRecord::Migration[7.2]
  def up
    Config::Submission.find_each do |submission|
      next unless submission.valid?
      app = submission.release_step_config.release_platform_config.release_platform.app
      submission.integrable = app
      submission.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
