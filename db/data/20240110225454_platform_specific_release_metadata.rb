class PlatformSpecificReleaseMetadata < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Release.all.each do |r|
        runs = r.release_platform_runs.includes(:release_platform)
        release_metadata = ReleaseMetadata.where(release: r).first

        next unless release_metadata

        if r.app.cross_platform?
          android = runs.where(release_platform: {platform: :android}).first
          ios = runs.where(release_platform: {platform: :ios}).first
          if android && ios
            release_metadata.update!(release_platform_run: android, promo_text: nil)
            release_metadata.dup.update!(release_platform_run: ios)
          elsif android
            release_metadata.update!(release_platform_run: android, promo_text: nil)
          elsif ios
            release_metadata.update!(release_platform_run: ios)
          end
        else
          release_metadata.update!(release_platform_run: runs.sole)
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
