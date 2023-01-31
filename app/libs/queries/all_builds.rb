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

  def initialize(app:)
    @app = app
  end

  def call
    results.map { |result| keys.zip(result).to_h }
  end

  private

  def results
    GitHub::SQL.results <<~SQL.squish, app_id: app.id
      SELECT 
        SR.build_version AS version_name,
        SR.build_number AS version_code,
        BA.generated_at AS build_generated_at,
        T.name AS train_name,
        S.name AS step_name
      FROM 
        build_artifacts BA 
        INNER JOIN train_step_runs SR ON BA.train_step_runs_id = SR.id
        INNER JOIN train_runs TR ON SR.train_run_id = TR.id
        INNER JOIN train_steps S ON SR.train_step_id = S.id
        INNER JOIN trains T ON S.train_id = T.id
        INNER JOIN apps A ON T.app_id = A.id
      WHERE a.id = :app_id
    SQL
  end

  def keys
    [
      :version_name,
      :version_code,
      :build_generated_at,
      :train_name,
      :step_name
    ]
  end

  attr_reader :app
end
