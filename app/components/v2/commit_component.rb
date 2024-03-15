class V2::CommitComponent < V2::BaseComponent
  def initialize(commit)
    @commit = commit
  end

  attr_reader :commit
  delegate :message, :author_name, :author_email, :author_login, :author_url, :timestamp, :short_sha, :team, :url, to: :commit

  def author_link
    author_url || "mailto:#{author_email}"
  end

  def author_info
    author_login || author_name
  end
end
