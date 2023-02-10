class Queries::Builds
  DEFAULT_SORT_COLUMN = "version_code"
  DEFAULT_SORT_DIRECTION = "desc"
  BASE_ATTR_MAPPING = {
    version_code: Releases::Step::Run.arel_table[:build_number],
    version_name: Releases::Step::Run.arel_table[:build_version],
    ci_link: Releases::Step::Run.arel_table[:ci_link],
    step_status: Releases::Step::Run.arel_table[:status],
    step_name: Releases::Step.arel_table[:name],
    train_name: Releases::Train.arel_table[:name],
    release_status: Releases::Train::Run.arel_table[:status]
  }
  ANDROID_ATTR_MAPPING =
    BASE_ATTR_MAPPING.merge(built_at: BuildArtifact.arel_table[:generated_at])
  IOS_ATTR_MAPPING =
    BASE_ATTR_MAPPING
      .merge(built_at: ExternalBuild.arel_table[:added_at], external_release_status: ExternalBuild.arel_table[:status])

  def self.all(**params)
    new(**params).all
  end

  def self.count(**params)
    new(**params).count
  end

  def initialize(app:, params:, sort_column: nil, sort_direction: nil)
    @app = app
    @params = params
    @sort_column = sort_column || DEFAULT_SORT_COLUMN
    @sort_direction = sort_direction || DEFAULT_SORT_DIRECTION
  end

  attr_reader :app, :sort_column, :sort_direction, :params
  delegate :android?, :ios?, to: :app

  def all
    return android_all if android?
    ios_all if ios?
  end

  def count
    return android_records.size if android?
    ios_records.size if ios?
  end

  def android_all
    selected_android_records.to_a.map do |record|
      deployments = record.step_run.step.deployments
      attributes =
        record
          .attributes
          .with_indifferent_access
          .merge(download_url: record.download_url)
          .merge(deployments: deployments)
          .except(:id, :train_step_runs_id)

      Queries::Build.new(attributes)
    end
  end

  def selected_android_records
    @selected_records ||=
      android_records
        .select(select_attrs(ANDROID_ATTR_MAPPING))
        .order("#{sort_column} #{sort_direction}")
        .limit(params.limit)
        .offset(params.offset)
  end

  def android_records
    @records ||=
      BuildArtifact
        .with_attached_file
        .joins(join_step_run_tree)
        .includes(step_run: {step: [deployments: :integration]})
        .select(:id, :train_step_runs_id)
        .where(apps: {id: app.id})
        .where(params.search_by(search_params))
        .where(params.filter_by(ANDROID_ATTR_MAPPING))
  end

  def ios_all
    selected_ios_records.to_a.map do |record|
      attributes =
        record
          .attributes
          .with_indifferent_access
          .merge(deployments: ios_deployments(record))
          .except(:id, :deployment_run_ids)

      Queries::Build.new(attributes)
    end
  end

  def selected_ios_records
    @selected_records ||=
      ios_records
        .select(select_attrs(IOS_ATTR_MAPPING.except(:version_code)))
        .order("#{sort_column} #{sort_direction}")
        .limit(params.limit)
        .offset(params.offset)
  end

  def ios_records
    @records ||=
      ExternalBuild
        .joins(deployment_run: [join_step_run_tree])
        .select("DISTINCT (external_builds.build_number) AS version_code")
        .select(distinct_deployment_runs)
        .where(apps: {id: app.id})
        .where(params.search_by(search_params))
        .where(params.filter_by(IOS_ATTR_MAPPING))
  end

  def ios_deployments(record)
    ios_deployment_runs.filter { |dr| dr.id.in?(record.deployment_run_ids) }.map(&:deployment)
  end

  def ios_deployment_runs
    @ios_deployment_runs ||= DeploymentRun.for_ids(selected_ios_records.flat_map(&:deployment_run_ids))
  end

  class Queries::Build
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

    def inspect
      format(
        "#<Queries::Build %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end

  private

  def join_step_run_tree
    {step_run: [{train_run: [{train: :app}]}, :step]}
  end

  def search_params
    {Releases::Step::Run.arel_table => %w[build_version build_number]}
  end

  def select_attrs(attrs_mapping)
    attrs_mapping.map do |attr_name, column|
      column.as(attr_name.to_s)
    end
  end

  def distinct_deployment_runs
    array_agg = Arel::Nodes::NamedFunction.new "array_agg", [ExternalBuild.arel_table[:deployment_run_id]]
    window = Arel::Nodes::Window.new.partition(ExternalBuild.arel_table[:build_number])
    array_agg.over(window).as("deployment_run_ids")
  end
end
