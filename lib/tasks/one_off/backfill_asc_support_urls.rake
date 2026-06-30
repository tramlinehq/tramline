# One-off: refresh store data for all apps, then backfill Support/Marketing URL
# onto existing release metadata for apps with a live release.
#
# Pass 1 (always): refresh each app's cached store data so channel_data carries
#   the new URL fields, and report which apps actually have URLs in the store.
# Pass 2 (APPLY=true): copy the per-locale URLs onto existing release_metadata
#   rows of active (live) releases — only the two URL columns, never notes.
#
# Idempotent. Skips apps without a store integration, only writes where the store
# actually has a URL, and leaves every other app/customer untouched.
#
# APPLY=true       writes (default is a dry run)
# APP_SLUGS=a,b    limit the sweep to specific app slugs (pilot before a full run)
namespace :one_off do
  desc "Refresh store data and backfill Support/Marketing URLs onto live release metadata (APPLY=true to write, APP_SLUGS=a,b to scope)"
  task backfill_asc_support_urls: :environment do
    apply = ENV["APPLY"] == "true"
    slugs = ENV["APP_SLUGS"].to_s.split(",").map(&:strip).compact_blank
    scope = slugs.any? ? App.where(slug: slugs) : App.all
    report = []

    puts(slugs.any? ? "Scoped to app slugs: #{slugs.join(", ")}" : "Sweeping all apps")

    scope.find_each do |app|
      # one bad app (failed store fetch, half-configured integration, etc.)
      # shouldn't abort the whole sweep — skip and log it.

      # support/marketing URLs are App Store-only, so iOS + cross-platform apps only
      next unless app.has_store_integration? && app.ready?
      next unless app.ios? || app.cross_platform?

      # 1. synchronous refresh — identical to RefreshExternalAppJob
      app.create_external!

      # 2. copy per-locale URLs onto live releases' existing iOS metadata rows
      app.release_platform_runs.where(status: [:created, :on_track]).find_each do |run|
        next unless run.ios?
        by_locale = (run.active_locales || []).index_by(&:locale)

        run.release_metadata.find_each do |metadata|
          data = by_locale[metadata.locale]
          next if data.nil?
          next if data.support_url.blank? && data.marketing_url.blank?

          report << {app: app.name, release: run.release_version, locale: metadata.locale,
                      support_url: data.support_url, marketing_url: data.marketing_url}

          if apply
            metadata.update!(support_url: data.support_url.presence,
              marketing_url: data.marketing_url.presence)
          end
        end
      end
    rescue => e
      puts "skip #{app.name}: #{e.class} - #{e.message}"
    end

    puts(apply ? "APPLIED #{report.size} row(s):" : "DRY RUN — #{report.size} row(s) would update:")
    report.each { |r| puts "  #{r[:app]} / #{r[:release]} / #{r[:locale]} — support=#{r[:support_url].inspect} marketing=#{r[:marketing_url].inspect}" }
    puts "apps affected: #{report.pluck(:app).uniq.size}"
  end
end
