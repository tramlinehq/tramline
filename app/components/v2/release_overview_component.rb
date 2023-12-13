class V2::ReleaseOverviewComponent < V2::BaseReleaseComponent

  def initialize(release)
    @release = release
    super(@release)
  end

  attr_reader :release

  def author_avatar
    user_avatar(release_author, limit: 2, size: 42, colors: 90)
  end

  def release_author
    release.app.organization.owner.full_name
  end

  def cross_platform?
    release.app.cross_platform?
  end

  def vcs_icon
    "integrations/logo_#{release.train.vcs_provider}.png"
  end

  def striped_header
    "bg-diagonal-stripes" if release.finished?
  end
end
