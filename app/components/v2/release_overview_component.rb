# frozen_string_literal: true
class V2::ReleaseOverviewComponent < V2::BaseComponent
  def author_avatar(name)
    user_avatar(name, limit: 2, size: 20, colors: 90)
  end

  def github_icon
    image_tag("integrations/logo_github.png", width: 14)
  end
end
