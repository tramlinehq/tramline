class Queries::ReleaseMetrics
  def self.call(**args)
    new(**args).call
  end

  def initialize(app:)
    @app = app
  end

  def call
    {
      release_history: release_history,
      avg_release_length: avg_release_length,
      avg_patches: avg_patches
    }
  end

  private

  attr_reader :app

  def avg_patches
    inner =
      app
        .train_runs
        .joins(:commits)
        .select("train_runs.id, COUNT(releases_commits.id) AS commit_count")
        .group("train_runs.id")
        .having("COUNT(releases_commits.id) > 1") # the base commit of the release branch is not counted as a patch

    Releases::Commit
      .select("AVG(commit_count) as average_commit_count")
      .from(inner)
      .to_a
      .first
      &.average_commit_count
      &.to_f
  end

  def avg_release_length
    app
      .train_runs
      .where
      .not(completed_at: nil)
      .average("(train_runs.completed_at - train_runs.created_at)")
  end

  HISTORY_DATE_FORMAT = "%b %Y"
  DEFAULT_HISTORY_PERIOD = :month

  def release_history
    app
      .runs
      .finished
      .group_by_period(DEFAULT_HISTORY_PERIOD, :completed_at, last: 10, current: true, format: HISTORY_DATE_FORMAT)
      .count
  end
end
