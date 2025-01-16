class Queries::Releases
  include Memery

  DEFAULT_SORT_COLUMN = "created_at"

  BASE_ATTR_MAPPING = {
    release_status: Release.arel_table[:status],
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
          .merge(all_commits: record.all_commits)
          .except(:id)

      Queries::Release.new(attributes)
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
    Release
      .joins(train: :app)
      .joins(:all_commits)
      .select(:id)
      .where(apps: {id: app.id})
      # TODO: Use pg_search instead of ILIKE
      .where("commits.message ILIKE ?", "%#{params.search_query}%")
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.filter_by(BASE_ATTR_MAPPING)))
  end

  class Queries::Release
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :release_status, :string
    attribute :all_commits, array: true, default: []
    # attribute :pull_requests, :array
    # attribute :release_changelog, :array

    def inspect
      format(
        "#<Queries::Release %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end

  private

  def search_params
    {Release.arel_table => %w[name status]}
  end

  def select_attrs(attrs_mapping)
    attrs_mapping.map do |attr_name, column|
      column.as(attr_name.to_s)
    end
  end
end 