class Queries::Releases
  include Memery

  DEFAULT_SORT_COLUMN = "releases.created_at"

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
      }

      # Zip the arrays together and separate by type
      items = record.types.zip(record.matched_messages, record.urls)

      attrs[:pull_requests] = items
        .select { |type, _, _| type == "pull_request" }
        .map { |_, message, url| { message: message, url: url } }

      attrs[:commits] = items
        .select { |type, _, _| type == "commit" }
        .map { |_, message, url| { message: message, url: url } }

      Queries::Release.new(attrs)
    end
  end

  def count
    selected_records.length
  end

  def selected_records
    records
      # .select(params.sort_column)
      .order(:created_at)
      .limit(params.limit)
      .offset(params.offset)
  end

  memoize def records
    # Define CTEs
    relevant_releases = Release
      .select(:id, :slug, :status, :created_at)
      .joins(:train)
      .where(trains: { app_id: app.id })

    filtered_commits = Commit
      .select(:id, "'commit' AS type", :release_id, "message AS matched_message", 
              :url,
              "relevant_releases.slug", "relevant_releases.status", "relevant_releases.created_at")
      .joins("JOIN (#{relevant_releases.to_sql}) AS relevant_releases ON commits.release_id = relevant_releases.id")
      .search_by_message(params.search_query)


    filtered_pull_requests = PullRequest
      .select(:id, "'pull_request' AS type", :release_id, "title AS matched_message", 
              :url,
              "relevant_releases.slug", "relevant_releases.status", "relevant_releases.created_at")
      .joins("JOIN (#{relevant_releases.to_sql}) AS relevant_releases ON pull_requests.release_id = relevant_releases.id")
      .search_by_title(params.search_query)

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
        "array_agg(url) as urls",
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
    attribute :pull_requests, array: true, default: [] # Queries::PullRequest
    attribute :commits, array: true, default: [] # Queries::Commit

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

  class Queries::PullRequest
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :title, :string
    attribute :number, :integer
    attribute :state, :string
    attribute :url, :string
    attribute :phase, :string

    def inspect
      format(
        "#<Queries::PullRequest %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end

  class Queries::Commit
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :commit_hash, :string
    attribute :message, :string
    attribute :author_name, :string
    attribute :url, :string
    attribute :timestamp, :datetime

    def inspect
      format(
        "#<Queries::Commit %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end
end 