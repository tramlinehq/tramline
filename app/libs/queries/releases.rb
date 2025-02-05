class Queries::Releases
  include Memery

  DEFAULT_SORT_COLUMN = "releases.created_at"

  def self.all(**params)
    new(**params).all
  end

  def self.count(**params)
    new(**params).count
  end

  def initialize(app:, params:, view_context: nil)
    @app = app
    @params = params
    params.sort_column ||= DEFAULT_SORT_COLUMN
    @view_context = view_context
  end

  attr_reader :app, :sort_column, :sort_direction, :params

  # TODO
  # - output structure
  # - pg_search
  #   - indexes
  # - tests
  # - pagination
  def all
    selected_records.map do |record|
      attrs = {
        id: record.release_id,
        release_slug: record.slug,
        release_status: record.status,
        release_version: record.release_version,
        release_branch: record.branch_name,
        created_at: record.created_at
      }

      items = record.types.zip(record.matched_messages, record.additional_data)

      attrs[:pull_requests] = items
        .select { |type, _, _, _| type == "pull_request" }
        .map do |_, message, data|
          {
            title: message,
            url: data["url"],
            state: data["state"],
            number: data["number"],
            source: data["source"],
            base_ref: data["base_ref"],
            head_ref: data["head_ref"],
            commit: nil, # TODO: we get the id, so need to construct Commit
            labels: data["labels"]
          }
        end

      attrs[:commits] = items
        .select { |type, _, _, _| type == "commit" }
        .map do |_, message, data|
          {
            message: message,
            url: data["url"],
            author_name: data["author_name"],
            commit_hash: data["commit_hash"],
            timestamp: data["timestamp"],
            author_email: data["author_email"],
            author_login: data["author_login"]
          }
        end

      release = Queries::Release.new(attrs)
      ReleasePresenter.new(release, @view_context)
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
      .select(:id, :slug, :status, :created_at, :release_version, :branch_name)
      .joins(:train)
      .where(trains: {app_id: app.id})

    filtered_commits = Commit
      .select(:id, "'commit' AS type", :release_id,
        "message AS matched_message",
        "jsonb_build_object('url', url, 'author_name', author_name, 'commit_hash', commit_hash, 'timestamp', commits.created_at, 'author_email', author_email, 'author_login', author_login) AS additional_data",
        "relevant_releases.slug", "relevant_releases.status", "relevant_releases.created_at", "relevant_releases.release_version", "relevant_releases.branch_name")
      .joins("JOIN (#{relevant_releases.to_sql}) AS relevant_releases ON commits.release_id = relevant_releases.id")

    filtered_commits = if params.search_query.present?
      filtered_commits.search_by_message(params.search_query).with_pg_search_highlight
    else
      filtered_commits.select("message AS pg_search_highlight")
    end

    filtered_pull_requests = PullRequest
      .select(:id, "'pull_request' AS type", :release_id,
        "title AS matched_message",
        "jsonb_build_object('url', url, 'state', state, 'number', number, 'source', source, 'base_ref', base_ref, 'head_ref', head_ref, 'commit', commit_id, 'labels', labels) AS additional_data",
        "relevant_releases.slug", "relevant_releases.status", "relevant_releases.created_at", "relevant_releases.release_version", "relevant_releases.branch_name")
      .joins("JOIN (#{relevant_releases.to_sql}) AS relevant_releases ON pull_requests.release_id = relevant_releases.id")

    filtered_pull_requests = if params.search_query.present?
      filtered_pull_requests.search(params.search_query).with_pg_search_highlight
    else
      filtered_pull_requests.select("title AS pg_search_highlight")
    end

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
        "array_agg(pg_search_highlight) as matched_messages",
        "array_agg(additional_data) as additional_data",
        :slug,
        :status,
        :release_version,
        :branch_name,
        :created_at)
      .group(:release_id, :slug, :status, :release_version, :branch_name, :created_at)
  end

  class Queries::Release
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :id, :string
    attribute :release_status, :string
    attribute :release_slug, :string
    attribute :release_version, :string
    attribute :release_branch, :string
    attribute :created_at, :datetime
    attribute :pull_requests, array: true, default: [] # Queries::PullRequest
    attribute :commits, array: true, default: [] # Queries::Commit

    def upcoming?
      release_status == "upcoming"
    end

    def status
      release_status
    end

    def branch_url
      "TODO"
    end

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
    attribute :source, :string
    attribute :base_ref, :string
    attribute :head_ref, :string
    attribute :commit, :string
    attribute :labels, array: true

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
    attribute :author_email, :string
    attribute :author_login, :string
    attribute :url, :string
    attribute :timestamp, :datetime

    def author_url
      nil # Component will handle nil gracefully
    end

    def author_link
      author_url
    end

    def author_info
      author_name
    end

    def short_sha
      commit_hash&.first(7)
    end

    def backmerge_failure?
      false
    end

    def show_avatar?
      false # Or true if you want to show avatars
    end

    def inspect
      format(
        "#<Queries::Commit %{attributes} >",
        attributes: attributes.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end
end
