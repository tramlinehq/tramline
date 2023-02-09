class Queries::Builds
  include ActiveModel::Model
  include ActiveModel::Attributes

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
    BASE_ATTR_MAPPING.merge({built_at: BuildArtifact.arel_table[:generated_at]})
  IOS_ATTR_MAPPING =
    BASE_ATTR_MAPPING.merge({built_at: ExternalBuild.arel_table[:added_at], external_release_status: ExternalBuild.arel_table[:status]})

  # ANDROID_ATTR_MAPPING.merge(IOS_ATTR_MAPPING).each do |name, _|
  #   attribute name, :string
  # end

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

  class << self
    def all(app:, sort_column:, sort_direction:, params:)
      sort_column ||= DEFAULT_SORT_COLUMN
      sort_direction ||= DEFAULT_SORT_DIRECTION

      if app.android?
        android(app, sort_column, sort_direction, params)
      elsif app.ios?
        ios(app, sort_column, sort_direction, params)
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

    def select_attrs(attrs_mapping)
      attrs_mapping.map do |attr_name, column|
        column.as(attr_name.to_s)
      end
    end

    def android(app, sort_column, sort_direction, params)
      records =
        base_android_query(app, params)
          .select(:id, :train_step_runs_id)
          .select(select_attrs(ANDROID_ATTR_MAPPING))
          .order("#{sort_column} #{sort_direction}")
          .limit(params.limit)
          .offset(params.offset)

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
        .where(params.filter_by(ANDROID_ATTR_MAPPING))
    end

    def ios(app, sort_column, sort_direction, params)
      records =
        base_ios_query(app, params)
          .select(:id, :deployment_run_id)
          .select(select_attrs(IOS_ATTR_MAPPING))
          .order("#{sort_column} #{sort_direction}")
          .limit(params.limit)
          .offset(params.offset)

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
      {step_run: [{train_run: [{train: :app}]}, :step]}
    end

    def search_params
      {Releases::Step::Run.arel_table => %w[build_version build_number]}
    end
  end

  def inspect
    format(
      "#<Queries::Builds %{attributes} >",
      attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
    )
  end
end
