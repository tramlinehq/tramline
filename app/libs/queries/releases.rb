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

  # TODO
  # - output structure
  # - pagination
  # - pg_search
  # - tests
  def all
    selected_records.map do |record|
      attrs = {
        release_slug: record.slug,
        release_status: record.status,
        created_at: record.created_at,
        types: record.types,
        matched_messages: record.matched_messages
      }

      Queries::Release.new(attrs)
    end
  end

  def count
    records.length
  end

  def selected_records
    records
      # .select(select_attrs(BASE_ATTR_MAPPING))
      # .select(params.sort_column)
      .order(:created_at)
      .limit(params.limit)
      .offset(params.offset)
  end

  memoize def records
    commits = Commit.arel_table
    pull_requests = PullRequest.arel_table

    # Define CTEs
    relevant_releases = Release
      .select(:id, :slug, :status, :created_at)
      .joins(:train)
      .where(trains: { app_id: app.id })

    filtered_commits = Commit
      .select(:id, "'commit' AS type", :release_id, "message AS matched_message", "relevant_releases.slug", "relevant_releases.status", "relevant_releases.created_at")
      .joins("JOIN (#{relevant_releases.to_sql}) AS relevant_releases ON commits.release_id = relevant_releases.id")
      .where(commits[:message].matches("%#{params.search_query}%"))

    filtered_pull_requests = PullRequest
      .select(:id, "'pull_request' AS type", :release_id, "title AS matched_message", "relevant_releases.slug", "relevant_releases.status", "relevant_releases.created_at")
      .joins("JOIN (#{relevant_releases.to_sql}) AS relevant_releases ON pull_requests.release_id = relevant_releases.id")
      .where(pull_requests[:title].matches("%#{params.search_query}%"))

    # Final query with CTEs
    Release
      .with(
        relevant_releases: relevant_releases,
        filtered_commits: filtered_commits,
        filtered_pull_requests: filtered_pull_requests,
        filtered_commits_and_pull_requests: filtered_commits.union(filtered_pull_requests)
      )
      .from("filtered_commits_and_pull_requests")
      .select(:release_id, 
        "array_agg(type) as types",
        "array_agg(matched_message) as matched_messages",
        :slug, 
        :status, 
        :created_at)
      .group(:release_id, :slug, :status, :created_at)
  end

  class Queries::Release
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :release_status, :string
    attribute :release_slug, :string
    attribute :created_at, :datetime
    attribute :matched_messages, array: true
    attribute :types, array: true
    attribute :pull_requests, Queries::PullRequest

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