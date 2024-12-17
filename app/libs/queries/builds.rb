class Queries::Builds
  include Memery

  DEFAULT_SORT_COLUMN = "version_code"

  BASE_ATTR_MAPPING = {
    version_code: Arel::Nodes::NamedFunction.new("CAST", [Build.arel_table[:build_number].as("integer")]),
    version_name: Build.arel_table[:version_name],
    ci_link: WorkflowRun.arel_table[:external_url],
    train_name: Train.arel_table[:name],
    platform: ReleasePlatform.arel_table[:platform],
    release_status: ReleasePlatformRun.arel_table[:status],
    built_at: Build.arel_table[:generated_at],
    kind: WorkflowRun.arel_table[:kind]
  }

  def self.all(**params)
    new(**params).all
  end

  def self.count(**params)
    new(**params).count
  end

  def initialize(app:, params:)
    @app = app
    @params = params
    params.sort_column ||= DEFAULT_SORT_COLUMN
  end

  attr_reader :app, :sort_column, :sort_direction, :params

  def all
    selected_records
      .to_a
      .map do |record|
      attributes =
        record
          .attributes
          .with_indifferent_access
          .merge(download_url: record.artifact&.download_url)
          .merge(submissions: record.store_submissions.order(created_at: :asc).filter(&:finished?).map(&:conf))
          .except(:id, :workflow_run_id)

      Queries::Build.new(attributes)
    end
  end

  def count
    selected_records.size
  end

  memoize def selected_records
    records
      .select(select_attrs(BASE_ATTR_MAPPING))
      .order(params.sort)
      .limit(params.limit)
      .offset(params.offset)
  end

  memoize def records
    Build
      .ready
      .joins(:workflow_run, release_platform_run: [{release_platform: [train: :app]}])
      .includes(:store_submissions)
      .select(:id, :workflow_run_id)
      .where(apps: {id: app.id})
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.search_by(search_params)))
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.filter_by(BASE_ATTR_MAPPING)))
  end

  class Queries::Build
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :version_name, :string
    attribute :version_code, :string
    attribute :built_at, :datetime
    attribute :train_name, :string
    attribute :platform, :string
    attribute :release_status, :string
    attribute :kind, :string
    attribute :ci_link, :string
    attribute :download_url, :string
    attribute :submissions, array: true, default: []

    def inspect
      format(
        "#<Queries::Build %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end

  private

  def search_params
    {Build.arel_table => %w[version_name build_number]}
  end

  def select_attrs(attrs_mapping)
    attrs_mapping.map do |attr_name, column|
      column.as(attr_name.to_s)
    end
  end
end
