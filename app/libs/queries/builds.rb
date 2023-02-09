class Queries::Builds
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :version_name, :string
  attribute :version_code, :string
  attribute :built_at, :datetime
  attribute :train_name, :string
  attribute :release_status, :string
  attribute :step_name, :string
  attribute :step_status, :string
  attribute :ci_link, :string
  attribute :download_url, :string
  attribute :deployments, array: true, default: []
  attribute :external_release_status, :string

  DEFAULT_SORT_COLUMN = "version_code"
  DEFAULT_SORT_DIRECTION = "desc"

  class << self
    def all(app:, limit:, offset:, sort_column:, sort_direction:, params:)
      sort_column ||= DEFAULT_SORT_COLUMN
      sort_direction ||= DEFAULT_SORT_DIRECTION

      if app.android?
        android(app, limit, offset, sort_column, sort_direction, params)
      elsif app.ios?
        ios(app, limit, offset, sort_column, sort_direction, params)
      end
    end

    def count(app:, params:)
      if app.android?
        base_android_query(app, params).size
      elsif app.ios?
        base_ios_query(app, params).size
      end
    end

    private

    def android(app, limit, offset, sort_column, sort_direction, params)
      records =
        base_android_query(app, params)
          .select(:id, :train_step_runs_id)
          .select("train_step_runs.build_version AS version_name")
          .select("train_step_runs.build_number AS version_code")
          .select("generated_at AS built_at")
          .select("trains.name AS train_name")
          .select("train_runs.status AS release_status")
          .select("train_steps.name AS step_name")
          .select("train_step_runs.status AS step_status")
          .select("train_step_runs.ci_link AS ci_link")
          .order("#{sort_column} #{sort_direction}")
          .limit(limit)
          .offset(offset)

      records.to_a.map do |record|
        deployments = record.step_run.step.deployments
        attributes =
          record
            .attributes
            .with_indifferent_access
            .merge(download_url: record.download_url)
            .merge(deployments: deployments)
            .except(:id, :train_step_runs_id)

        new(attributes)
      end
    end

    def base_android_query(app, params)
      BuildArtifact
        .with_attached_file
        .joins(join_step_run_tree)
        .includes(step_run: {step: [deployments: :integration]})
        .where(apps: {id: app.id})
        .where(params.search_by(search_params))
    end

    def ios(app, limit, offset, sort_column, sort_direction, params)
      records =
        base_ios_query(app, params)
          .select(:id, :deployment_run_id)
          .select("train_step_runs.build_version AS version_name")
          .select("external_builds.added_at AS built_at")
          .select("trains.name AS train_name")
          .select("train_runs.status AS release_status")
          .select("external_builds.status AS external_release_status")
          .select("train_steps.name AS step_name")
          .select("train_step_runs.status AS step_status")
          .select("train_step_runs.ci_link AS ci_link")
          .order("#{sort_column} #{sort_direction}")
          .limit(limit)
          .offset(offset)

      records.to_a.map do |record|
        attributes =
          record
            .attributes
            .with_indifferent_access
            .merge(deployments: record.deployment_run.step_run.step.deployments)
            .except(:id, :deployment_run_id)

        new(attributes)
      end
    end

    def base_ios_query(app, params)
      ExternalBuild
        .joins(deployment_run: [join_step_run_tree])
        .includes(deployment_run: {step_run: {step: [deployments: :integration]}})
        .select("DISTINCT ON (external_builds.build_number) external_builds.build_number AS version_code")
        .where(apps: {id: app.id})
        .where(params.search_by(search_params))
    end

    def join_step_run_tree
      {
        step_run: [
          {train_run: [{train: :app}]},
          :step
        ]
      }
    end

    def search_params
      {
        Releases::Step::Run.arel_table => %w[build_version build_number]
      }
    end
  end

  def inspect
    format(
      "#<Queries::Builds %{attributes} >",
      attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
    )
  end
end
