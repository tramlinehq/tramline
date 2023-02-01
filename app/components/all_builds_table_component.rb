class AllBuildsTableComponent < ViewComponent::Base
  def initialize(app:)
    @app = app
  end

  def all_builds
    @app.all_builds
  end
end
