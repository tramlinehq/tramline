# frozen_string_literal: true

# FIXME: All uses of the `Semantic::Version` library have been replaced with an internal SemVer handler.
# But the gem is kept around because this backfill migration depends on it.
class BackfillOriginalReleaseVersion < ActiveRecord::Migration[7.0]
  def up
    return

    ReleasePlatformRun.all.each do |release|
      commit_count = release.commits.size

      if commit_count == 0 || commit_count == 1
        release.original_release_version = release.release_version
      else
        release_semver = Semantic::Version.new(release.release_version)
        release_major = release_semver.major
        release_minor = release_semver.minor
        release_patch = release_semver.patch
        release_patch_int = release_patch.to_i

        # ignore releases that already adhere to not bumping patch version on every commit
        # this should not really be the case on production, but it's just a failsafe for dev/staging.
        if release_patch_int != (commit_count - 1)
          release.original_release_version = release.release_version
          release.save!
          next
        end

        corrected_release_patch_int = 0
        original_release_semver = Semantic::Version.new("#{release_major}.#{release_minor}.#{corrected_release_patch_int}")
        release.original_release_version = original_release_semver.to_s
      end

      release.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
