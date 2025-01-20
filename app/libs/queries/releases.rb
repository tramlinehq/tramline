class Queries::Releases
  include Memery

  DEFAULT_SORT_COLUMN = "releases.created_at"

  BASE_ATTR_MAPPING = {
    release_slug: Release.arel_table[:slug],
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
          .merge(
            # commits: Array(record.commits_data).map { |c| JSON.parse(c) },
            # pull_requests: Array(record.pull_requests_data).map { |pr| JSON.parse(pr) }
          )
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
      .select(params.sort_column)
      .order(params.sort)
      .limit(params.limit)
      .offset(params.offset)
  end

  memoize def records
    Release
      .joins(train: :app)
      .left_joins(:all_commits)
      .left_joins(:pull_requests)
      .select(:id)
      .select("commits.commit_hash as commit_hash")
      .select("commits.message as commit_message")
      .select("pull_requests.title as pull_request_title")
      .distinct
      .where(apps: {id: app.id})
      # TODO: Use pg_search instead of ILIKE
      .where("commits.message ILIKE ? OR pull_requests.title ILIKE ?", "%#{params.search_query}%", "%#{params.search_query}%")
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.filter_by(BASE_ATTR_MAPPING)))
  end

  class Queries::Release
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :release_status, :string
    attribute :release_slug, :string
    attribute :created_at, :datetime
    attribute :commit_hash, :string
    attribute :commit_message, :string
    attribute :pull_request_title, :string
    # attribute :release_changelog, :array

    def inspect
      format(
        "#<Queries::Release %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end

  private

  def select_attrs(attrs_mapping)
    attrs_mapping.map do |attr_name, column|
      column.as(attr_name.to_s)
    end
  end
end 