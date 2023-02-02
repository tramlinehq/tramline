# version name
# version code
# datetime of build gen
# was shipped?
# train
# step
# deployments
class Queries::AllBuilds
  def self.call(**params)
    new(**params).call
  end

  DEFAULT_SORT_COLUMN = "version_code"
  DEFAULT_SORT_DIRECTION = "desc"

  def initialize(app:, column: DEFAULT_SORT_COLUMN, direction: DEFAULT_SORT_DIRECTION)
    @app = app
    @column = column
    @direction = direction
  end

  attr_reader :app, :column, :direction

  def call
    BuildArtifact
      .joins(step_run: [{train_run: [{train: :app}]}, :step])
      .where(apps: {id: app.id})
      .order("#{column} #{direction}")
      # .select("COUNT(1) FILTER (WHERE train_runs.status = 'finished') AS released")
      .select("train_step_runs.build_version AS version_name")
      .select("train_step_runs.build_number AS version_code")
      .select("generated_at AS build_generated_at")
      .select("trains.name AS train_name")
      .select("train_runs.status AS release_status")
      .select("train_steps.name AS step_name")
      .select("train_step_runs.status AS step_status")
  end
end
