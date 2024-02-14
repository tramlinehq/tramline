# frozen_string_literal: true

class PopulateSendBuildNotesOnDeployments < ActiveRecord::Migration[7.0]
  def up
    return
    ActiveRecord::Base.transaction do
      Deployment.all.each do |deployment|
        next if deployment.production_channel?
        deployment.update!(send_build_notes: true)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
