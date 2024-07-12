# frozen_string_literal: true

class V2::LiveRelease::CurrentPreProdReleaseComponent < ViewComponent::Base
  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  attr_reader :release_platform_run

  def changed_commits
    V2::CommitComponent.with_collection(Build.first.commit.release.all_commits.sample(rand(1..5)))
  end
end
