# frozen_string_literal: true

class V2::LiveRelease::SubmissionConfigComponent < V2::BaseComponent
  def initialize(release_config, release_platform_run:)
    @release_config = release_config
    @release_platform_run = release_platform_run
  end

  attr_reader :release_config, :release_platform_run
end
