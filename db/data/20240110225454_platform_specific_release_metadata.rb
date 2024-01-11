class PlatformSpecificReleaseMetadata < ActiveRecord::Migration[7.0]
  def up
    Release.all.each do |r|
      run1 = r.release_platform_runs.first
      run2 = r.release_platform_runs.second

      if r.app.cross_platform?
        dup_release_metadata = r.release_metadata.dup
        current_release_platform = r.release_metadata.release_platform_run
        if current_release_platform.blank?
          r.release_metadata.update!(release_platform_run: run1)
          dup_release_metadata.update!(release_platform_run: run2)
        else
          run = [run1, run2].reject { |rpr| rpr == current_release_platform }.first
          dup_release_metadata.update!(release_platform_run: run)
        end
      else
        r.release_metadata.update!(release_platform_run: run1)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
