class PlatformSpecificReleaseMetadata < ActiveRecord::Migration[7.0]
  def up
    Release.all.each do |r|
      if r.app.cross_platform?
        android = r.release_platform_runs.android.sole
        ios = r.release_platform_runs.ios.sole
        dup_release_metadata = r.release_metadata.dup
        r.release_metadata.update!(release_platform_run: android, promo_text: nil)
        dup_release_metadata.update!(release_platform_run: ios)
      else
        r.release_metadata.update!(release_platform_run: r.release_platform_runs.sole)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
