class V2::CommitComponent < V2::BaseComponent
  def initialize(commit, avatar: true)
    @commit = commit
    @avatar = avatar
  end

  attr_reader :commit
  delegate :message, :author_name, :author_email, :author_login, :author_url, :timestamp, :short_sha, :url, :team, to: :commit

  def author_link
    author_url || "mailto:#{author_email}"
  end

  def author_info
    author_login || author_name
  end

  def integration_provider_logo
    "integrations/logo_#{ci_cd_provider}.png"
  end

  def ci_cd_provider
    commit.train&.ci_cd_provider
  end

  def show_avatar?
    @avatar
  end

  def show_numbering?
    @numbering
  end
end
