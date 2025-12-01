namespace :year_wrapped do
  desc "Generate year wrapped stats for an app"
  task :generate, %i[app_slug year] => :environment do |_, args|
    app_slug = args[:app_slug]
    year = args[:year]&.to_i || Time.current.year

    if app_slug.blank?
      puts "Error: App slug is required"
      puts "Usage: rails year_wrapped:generate[APP_SLUG,YEAR]"
      puts "Example: rails year_wrapped:generate[my-awesome-app,2024]"
      exit 1
    end

    app = App.find_by(slug: app_slug)
    unless app
      puts "Error: App with slug '#{app_slug}' not found"
      exit 1
    end

    puts "Generating Year Wrapped Stats for #{app.name} (#{year})..."
    puts "🏢 Organization: #{app.organization.name}"
    puts "📱 App: #{app.name} (#{app.bundle_identifier})"
    puts "=" * 60

    # Only consider trains with production deployments for the specific app
    trains_with_production = app.trains.filter(&:has_production_deployment?)

    if trains_with_production.empty?
      puts "No trains with production deployments found for app: #{app.name}"
      exit 0
    end

    puts "Found #{trains_with_production.count} trains with production deployments"
    puts "-" * 60

    begin
      stats = Queries::YearWrappedStats.call(app, year)
      output_stats(stats)
    rescue => e
      puts "Error processing app #{app.name} (ID: #{app.id}): #{e.message}"
      exit 1
    end

    puts "\n🎉 Year wrapped generation complete for #{app.name}!"
  end

  private

  def output_stats(stats)
    puts "📊 Year #{stats[:data_period]} Stats:"
    puts "🚃 Active Trains: #{stats[:trains_count]}"
    puts "🚀 Production Releases: #{stats[:production_releases_count]}"
    puts "💾 Total Commits Shipped: #{stats[:total_commits]}"
    puts "🔨 Total Builds Generated: #{stats[:total_builds]}"
    puts "🔧 Patch/Hotfixes per Release: #{stats[:patch_fixes_per_release]}"
    puts "📈 Reldex Average: #{stats[:reldex_average]&.round(2) || 'N/A'}"
    puts "🏆 Best Reldex: #{stats[:reldex_best]&.round(2) || 'N/A'} (#{stats[:reldex_best_release] || 'N/A'})"
    puts "📉 Worst Reldex: #{stats[:reldex_worst]&.round(2) || 'N/A'} (#{stats[:reldex_worst_release] || 'N/A'})"
    puts "🔥 Month with Most Releases: #{stats[:busiest_month]} (#{stats[:busiest_month_count]} releases)"
    puts "😴 Month with Least Releases: #{stats[:quietest_month]} (#{stats[:quietest_month_count]} releases)"
    puts "📝 Release with Most Changes: #{stats[:most_changes_release]} (#{stats[:most_changes_count]} commits)"
    puts "⚡ Release with Least Changes: #{stats[:least_changes_release]} (#{stats[:least_changes_count]} commits)"
    puts "🐌 Longest Release Duration: #{stats[:longest_release]} (#{format_duration(stats[:longest_release_duration])})"
    puts "🏃 Shortest Release Duration: #{stats[:shortest_release]} (#{format_duration(stats[:shortest_release_duration])})"
    puts "⏱️ Average Release Duration: #{format_duration(stats[:average_release_duration])}"
    puts "🎖️ Most Active Release Pilot: #{stats[:most_active_pilot]}"
    puts "🏆 Top Contributor: #{stats[:top_contributor]}"

    # Only show growth stats if we have previous year data
    growth_stats = []
    growth_stats << "🚀 Growth vs Previous Year: #{stats[:growth_vs_previous_year]}" if stats[:growth_vs_previous_year]
    growth_stats << "⚡ Velocity Improvement: #{stats[:velocity_improvement]}" if stats[:velocity_improvement]

    if growth_stats.any?
      puts ""
      puts "📈 Growth Stats:"
      growth_stats.each { |stat| puts stat }
    end
  end

  def format_duration(duration_seconds)
    return 'N/A' unless duration_seconds&.positive?

    # Convert to integer to avoid decimal precision issues
    total_seconds = duration_seconds.round

    days = total_seconds / 86400
    hours = (total_seconds % 86400) / 3600
    minutes = (total_seconds % 3600) / 60

    # Choose the most appropriate unit based on duration
    if days >= 7
      weeks = days / 7
      remaining_days = days % 7
      if remaining_days > 0
        "#{weeks}w #{remaining_days}d"
      else
        "#{weeks}w"
      end
    elsif days > 0
      if hours > 0
        "#{days}d #{hours}h"
      else
        "#{days}d"
      end
    elsif hours > 0
      if minutes > 0
        "#{hours}h #{minutes}m"
      else
        "#{hours}h"
      end
    else
      "#{minutes}m"
    end
  end
end
