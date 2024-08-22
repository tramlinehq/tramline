# colocated calls, giant join query once
# caching
# cache timelines are different
# complex queries
class Queries::ReleaseBreakdown
  using RefinedEnumerable
  include Loggable

  PARTS = %i[hotfixes team_stability_commits team_release_commits reldex].freeze

  def self.warm(release_id, parts = PARTS)
    validate_parts!(parts)
    new(release_id).warm(parts)
  end

  def self.validate_parts!(parts)
    raise ArgumentError, "Invalid parts: #{parts}" if parts.any? { |part| PARTS.exclude?(part) }
  end

  def initialize(release_id)
    @release_id = release_id
  end

  def warm(parts)
    validate_parts!(parts)
    parts.each { |part| cache.write(cache_key(part), public_send(part)) }
  rescue => e
    elog(e)
  end

  def team_stability_commits
    cache.fetch(cache_key(:team_stability_commits)) do
      release.stability_commits.count_by_team(release.organization)
    end
  end

  def team_release_commits
    cache.fetch(cache_key(:team_release_commits)) do
      release.release_changelog&.commits_by_team
    end
  end

  def hotfixes
    cache.fetch(cache_key(:hotfixes)) do
      release.all_hotfixes.map { |r| [r.release_version, r.live_release_link] }.to_h
    end
  end

  def reldex
    cache.fetch(cache_key(:reldex)) do
      release.index_score
    end
  end

  delegate :validate_parts!, to: self

  private

  delegate :cache, to: Rails

  def release
    @release ||= Release
      .where(id: @release_id)
      .includes(:all_commits, :pull_requests, train: [:release_platforms])
      .sole
  end

  def thaw
    PARTS.each { |part| cache.delete(cache_key(part)) }
  end

  def cache_key(part)
    "release/#{@release_id}/#{part}"
  end
end
