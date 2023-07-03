# frozen_string_literal: true

class AddReleaseVersionToReleasePlatformRuns < ActiveRecord::Migration[7.0]
  def up
    ReleasePlatformRun.where(release_version: nil).each do |run|
      run.update(release_version: run.release.attributes["release_version"])
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
