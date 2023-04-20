class Queries::ReleaseMetrics
  def self.call(**args)
    new(**args).call
  end

  def initialize(app:)
    @app = app
  end

  def call
    {
      history: history,
      avg_length: avg_length,
      avg_patches: avg_patches
    }
  end

  private

  def avg_patches
    inner =
      @app
        .train_runs
        .left_outer_joins(:commits)
        .select("train_runs.id, COUNT(releases_commits.id) AS commit_count")
        .group("train_runs.id")

    Releases::Commit
      .select("AVG(commit_count) as average_commit_count")
      .from(inner)
      .to_a
      .first
      &.average_commit_count
      &.to_f
  end

  def avg_length
    @app
      .train_runs
      .where
      .not(completed_at: nil)
      .average("(train_runs.completed_at - train_runs.created_at)")
  end

  def history
    @app
      .train_runs
      .group_by_month(:created_at)
      .count
  end
end
