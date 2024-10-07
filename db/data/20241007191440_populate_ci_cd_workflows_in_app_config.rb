# frozen_string_literal: true

class PopulateCiCdWorkflowsInAppConfig < ActiveRecord::Migration[7.2]
  def up
    ActiveRecord::Base.transaction do
      Train.find_each do |train|
        next if train.ci_cd_provider.blank?
        train.set_ci_cd_workflows
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
