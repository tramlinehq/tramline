class PlatformSpecificReleaseMetadata < ActiveRecord::Migration[7.0]
  def up
    Release.all.each do |r|
      runs = r.release_platform_runs.includes(:release_platform)

      if r.app.cross_platform?
        android = runs.where(release_platform: {platform: :android}).first
        ios = runs.where(release_platform: {platform: :ios}).first
        if android && ios
          r.release_metadata.update!(release_platform_run: android, promo_text: nil)
          r.release_metadata.dup.update!(release_platform_run: ios)
        elsif android
          r.release_metadata.update!(release_platform_run: android, promo_text: nil)
        elsif ios
          r.release_metadata.update!(release_platform_run: ios)
        end
      else
        r.release_metadata.update!(release_platform_run: runs.sole)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
