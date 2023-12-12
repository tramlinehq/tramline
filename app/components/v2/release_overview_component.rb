# frozen_string_literal: true
class V2::ReleaseOverviewComponent < V2::BaseComponent

  def initialize(release)
    @release = release
  end

  attr_reader :release

  def author_avatar
    user_avatar(release_author, limit: 2, size: 42, colors: 90)
  end

  def github_icon
    image_tag("integrations/logo_github.png", width: 14)
  end

  def release_author
    release.app.organization.owner.full_name
  end

  def started_at
    time_format release.scheduled_at, with_time: false, with_year: true
  end

  def released_at
    time_format release.completed_at, with_time: false, with_year: true
  end

  def duration
    return "–" unless release.completed_at
    distance_of_time_in_words(release.scheduled_at, release.completed_at)
  end

  def release_branch
    release.release_branch
  end

  def release_tag
    release.tag_name
  end

  def cross_platform?
    release.app.cross_platform?
  end

  def build_info(deployment_run)
    step_run = deployment_run.step_run
    "#{step_run.build_version} (#{step_run.build_number})"
  end

  def build_deployed_at(deployment_run)
    "Last build deployed #{ago_in_words deployment_run.updated_at}"
  end
end
