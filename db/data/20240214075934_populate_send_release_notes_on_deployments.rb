# frozen_string_literal: true

class PopulateSendReleaseNotesOnDeployments < ActiveRecord::Migration[7.0]
  def up
    return
    ActiveRecord::Base.transaction do
      Deployment.all.each do |deployment|
        if deployment.send_build_notes?
          deployment.update!(notes: "build_notes")
        elsif deployment.production_channel?
          deployment.update!(notes: "release_notes")
        else
          deployment.update!(notes: "no_notes")
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
