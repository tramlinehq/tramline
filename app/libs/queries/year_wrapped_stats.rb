class Queries::YearWrappedStats
  include Memery

  def self.call(app, year = Time.current.year)
    new(app, year).call
  end

  def initialize(app, year = Time.current.year)
    @app = app
    @year = year
    @start_date = Date.new(year, 1, 1).beginning_of_year
    @end_date = Date.new(year, 12, 31).end_of_year
  end

  def call
    {
      app_id: app.id,
      app_name: app.name,
      app_bundle_identifier: app.bundle_identifier,
      organization_name: app.organization.name,
      year: year,
      data_period: data_period,
      trains_count: trains_with_production.count,
      production_releases_count: production_releases_count,
      total_commits: total_commits,
      total_builds: total_builds,
      patch_fixes_per_release: patch_fixes_per_release,
      reldex_average: reldex_average,
      reldex_best: reldex_best,
      reldex_best_release: reldex_best_release,
      reldex_worst: reldex_worst,
      reldex_worst_release: reldex_worst_release,
      busiest_month: busiest_month,
      busiest_month_count: busiest_month_count,
      quietest_month: quietest_month,
      quietest_month_count: quietest_month_count,
      most_changes_release: most_changes_release,
      most_changes_count: most_changes_count,
      least_changes_release: least_changes_release,
      least_changes_count: least_changes_count,
      longest_release: longest_release,
      longest_release_duration: longest_release_duration,
      shortest_release: shortest_release,
      shortest_release_duration: shortest_release_duration,
      average_release_duration: average_release_duration,
      most_active_pilot: most_active_pilot,
      growth_vs_previous_year: growth_vs_previous_year,
      velocity_improvement: velocity_improvement,
      top_contributor: top_contributor
    }
  end

  private

  attr_reader :app, :year, :start_date, :end_date

  memoize def trains_with_production
    app.trains.filter(&:has_production_deployment?)
  end

  # .includes(:release_platform_runs, :all_commits, :release_index, :train)
  memoize def year_releases
    Release
      .joins(:train)
      .where(train: trains_with_production)
      .where(completed_at: start_date..end_date)
      .finished
  end

  memoize def production_releases_count
    year_releases.count
  end

  memoize def total_commits
    year_releases.sum do |release|
      all_commits_count = release.all_commits.count
      changelog_commits_count = release.release_changelog&.commits&.count || 0
      all_commits_count + changelog_commits_count
    end
  end

  memoize def total_builds
    year_releases.sum do |release|
      release.release_platform_runs.flat_map(&:builds).count
    end
  end

  memoize def patch_fixes_per_release
    return 0.0 if production_releases_count.zero?

    total_patch_fixes = year_releases.sum do |release|
      release.release_platform_runs.sum do |run|
        # Count additional production releases beyond the first one as patch fixes
        [run.production_releases.count - 1, 0].max
      end
    end

    (total_patch_fixes.to_f / production_releases_count).round(2)
  end

  memoize def reldex_scores
    year_releases.filter_map do |release|
      score = release.index_score&.value
      next unless score
      {release: release.release_version, score: score}
    end
  end

  memoize def reldex_average
    return nil if reldex_scores.empty?
    reldex_scores.sum { |r| r[:score] } / reldex_scores.size.to_f
  end

  memoize def reldex_best
    return nil if reldex_scores.empty?
    reldex_scores.max_by { |r| r[:score] }&.dig(:score)
  end

  memoize def reldex_best_release
    return nil if reldex_scores.empty?
    reldex_scores.max_by { |r| r[:score] }&.dig(:release)
  end

  memoize def reldex_worst
    return nil if reldex_scores.empty?
    reldex_scores.min_by { |r| r[:score] }&.dig(:score)
  end

  memoize def reldex_worst_release
    return nil if reldex_scores.empty?
    reldex_scores.min_by { |r| r[:score] }&.dig(:release)
  end

  memoize def releases_by_month
    year_releases.group_by { |release| release.completed_at.strftime("%B") }
  end

  memoize def busiest_month
    return "N/A" if releases_by_month.empty?
    releases_by_month.max_by { |_, releases| releases.count }.first
  end

  memoize def busiest_month_count
    return 0 if releases_by_month.empty?
    releases_by_month.max_by { |_, releases| releases.count }.last.count
  end

  memoize def quietest_month
    return "N/A" if releases_by_month.empty?
    # Only consider months that had releases
    releases_by_month.min_by { |_, releases| releases.count }.first
  end

  memoize def quietest_month_count
    return 0 if releases_by_month.empty?
    releases_by_month.min_by { |_, releases| releases.count }.last.count
  end

  memoize def releases_with_commit_counts
    year_releases.map do |release|
      all_commits_count = release.all_commits.count
      changelog_commits_count = release.release_changelog&.commits&.count || 0
      total_commits = all_commits_count + changelog_commits_count

      {
        release: release.release_version,
        commits: total_commits,
        duration: release.duration&.seconds,
        release_type: release.release_type
      }
    end
  end

  memoize def regular_releases_with_commits
    releases_with_commit_counts.select { |r| r[:release_type] == "release" }
  end

  memoize def most_changes_release
    return "N/A" if regular_releases_with_commits.empty?
    regular_releases_with_commits.max_by { |r| r[:commits] }&.dig(:release)
  end

  memoize def most_changes_count
    return 0 if regular_releases_with_commits.empty?
    regular_releases_with_commits.max_by { |r| r[:commits] }&.dig(:commits)
  end

  memoize def least_changes_release
    return "N/A" if regular_releases_with_commits.empty?
    regular_releases_with_commits.min_by { |r| r[:commits] }&.dig(:release)
  end

  memoize def least_changes_count
    return 0 if regular_releases_with_commits.empty?
    regular_releases_with_commits.min_by { |r| r[:commits] }&.dig(:commits)
  end

  memoize def releases_with_duration
    releases_with_commit_counts.select { |r| r[:duration]&.positive? && r[:release_type] == "release" }
  end

  memoize def longest_release
    return "N/A" if releases_with_duration.empty?
    releases_with_duration.max_by { |r| r[:duration] }&.dig(:release)
  end

  memoize def longest_release_duration
    return nil if releases_with_duration.empty?
    releases_with_duration.max_by { |r| r[:duration] }&.dig(:duration)
  end

  memoize def shortest_release
    return "N/A" if releases_with_duration.empty?
    releases_with_duration.min_by { |r| r[:duration] }&.dig(:release)
  end

  memoize def shortest_release_duration
    return nil if releases_with_duration.empty?
    releases_with_duration.min_by { |r| r[:duration] }&.dig(:duration)
  end

  memoize def average_release_duration
    return nil if releases_with_duration.empty?
    releases_with_duration.sum { |r| r[:duration] } / releases_with_duration.size.to_f
  end

  memoize def most_active_pilot
    pilots_with_count = year_releases
      .filter_map(&:release_pilot)
      .group_by(&:itself)
      .transform_values(&:count)

    return "N/A" if pilots_with_count.empty?

    most_active = pilots_with_count.max_by { |pilot, count| count }
    most_active.first.name
  end

  memoize def previous_year_releases
    previous_start = Date.new(year - 1, 1, 1).beginning_of_year
    previous_end = Date.new(year - 1, 12, 31).end_of_year

    Release
      .joins(:train)
      .where(train: trains_with_production)
      .where(completed_at: previous_start..previous_end)
      .finished
  end

  memoize def growth_vs_previous_year
    previous_count = previous_year_releases.count
    current_count = production_releases_count

    return nil if previous_count.zero?

    growth_percentage = ((current_count - previous_count).to_f / previous_count * 100).round

    if growth_percentage > 0
      "+#{growth_percentage}%"
    elsif growth_percentage < 0
      "#{growth_percentage}%"
    else
      "0%"
    end
  end

  memoize def velocity_improvement
    previous_durations = previous_year_releases
      .select { |release| release.duration&.seconds&.positive? && release.release_type == "release" }
      .map { |release| release.duration.seconds }

    current_durations = releases_with_duration.pluck(:duration)

    return nil if previous_durations.empty? || current_durations.empty?

    previous_avg = previous_durations.sum / previous_durations.size.to_f
    current_avg = current_durations.sum / current_durations.size.to_f

    improvement_percentage = ((previous_avg - current_avg) / previous_avg * 100).round

    if improvement_percentage > 0
      "#{improvement_percentage}% faster"
    elsif improvement_percentage < 0
      "#{improvement_percentage.abs}% slower"
    else
      "Same pace"
    end
  end

  memoize def top_contributor
    # Get all commits from year releases and group by author email
    contributor_commits = year_releases.flat_map(&:all_commits)
      .reject { |commit| bot_email?(commit.author_name) }
      .group_by(&:author_name)
      .transform_values(&:count)

    return "N/A" if contributor_commits.empty?

    top_email = contributor_commits.max_by { |email, count| count }.first

    # Try to get a cleaner name from the email or commits
    sample_commit = year_releases.flat_map(&:all_commits).find { |c| c.author_email == top_email }
    sample_commit&.author_name || top_email.split("@").first.humanize
  end

  def bot_email?(name)
    return false if name.blank?

    bot_patterns = [
      /bot/i,
      /noreply/i,
      /automation/i,
      /ci/i,
      /github-actions/i,
      /dependabot/i,
      /renovate/i,
      /tramline/i
    ]

    bot_patterns.any? { |pattern| name.match?(pattern) }
  end

  memoize def data_period
    return year.to_s if year_releases.empty?

    earliest_release = year_releases.min_by(&:completed_at)
    latest_release = year_releases.max_by(&:completed_at)

    earliest_month = earliest_release.completed_at.strftime("%b")
    latest_month = latest_release.completed_at.strftime("%b")

    if earliest_month == "Jan" && latest_month == "Dec"
      year.to_s
    elsif earliest_month == latest_month
      "#{year} (#{earliest_month})"
    else
      "#{year} (#{earliest_month}-#{latest_month})"
    end
  end
end
