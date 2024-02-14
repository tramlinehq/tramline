# frozen_string_literal: true

class PopulateSendReleaseNotesOnDeployments < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Deployment.all.each do |deployment|
        next unless deployment.production_channel?
        deployment.update!(send_release_notes: true)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
