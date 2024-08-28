class V2::CommitComponent < V2::BaseComponent
  include ReleasesHelper
  OUTER_CLASSES = "py-1.5 px-2 hover:bg-main-100 hover:border-main-100 hover:first:rounded-sm hover:last:rounded-sm"

  def initialize(commit:, avatar: true, detailed: true)
    @commit = commit
    @avatar = avatar
    @detailed = detailed
  end

  attr_reader :commit
  delegate :message, :author_name, :author_email, :author_login, :author_url, :timestamp, :short_sha, :url, to: :commit

  def author_link
    author_url || "mailto:#{author_email}"
  end

  def author_info
    author_login || author_name
  end

  def detailed? = @detailed

  def show_avatar? = @avatar

  def pull_request
    @commit.pull_request
  end

  def outer_classes
    return "" unless detailed?
    OUTER_CLASSES
  end

  def team
    @team ||= @commit.team
  end
end
