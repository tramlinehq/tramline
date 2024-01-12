class PlatformSpecificReleaseMetadata < ActiveRecord::Migration[7.0]
  def up
    Release.all.each do |r|
      runs = r.release_platform_runs.includes(:release_platform)

      if r.app.cross_platform?
        android = runs.where(release_platform: { platform: :android }).sole
        ios = runs.where(release_platform: { platform: :ios }).sole
        dup_release_metadata = r.release_metadata.dup
        r.release_metadata.update!(release_platform_run: android, promo_text: nil)
        dup_release_metadata.update!(release_platform_run: ios)
      else
        r.release_metadata.update!(release_platform_run: runs.sole)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
