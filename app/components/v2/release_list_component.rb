# frozen_string_literal: true

class V2::ReleaseListComponent < V2::BaseComponent
  include Memery

  def initialize(train:)
    @train = train
  end

  attr_reader :train
  delegate :app, to: :train

  def devops_report
    train.devops_report
  end

  def hotfix_from
    train.hotfix_from
  end

  def empty?
    previous_releases.empty? &&
      ongoing_release.nil? &&
      upcoming_release.nil? &&
      hotfix_release.nil? &&
      last_completed_release.nil?
  end

  memoize def previous_releases
    train
      .releases
      .completed
      .where.not(id: [ongoing_release, upcoming_release, hotfix_release, last_completed_release])
      .order(scheduled_at: :desc)
      .take(10)
  end

  memoize def last_completed_release
    train.releases.released.first
  end

  memoize def ongoing_release
    train.ongoing_release
  end

  memoize def upcoming_release
    train.upcoming_release
  end

  memoize def hotfix_release
    train.hotfix_release
  end

  def ordered_releases
    train.releases.order(scheduled_at: :desc).take(100)
  end

  def release_interval(run)
    "#{release_start_time(run)} – #{release_end_time(run)}"
  end

  def release_start_time(run)
    time_format run.scheduled_at, with_time: false, dash_empty: true
  end

  def release_end_time(run)
    time_format run.completed_at, with_time: false, dash_empty: true
  end

  def release_duration(run)
    return "–" unless run.completed_at
    distance_of_time_in_words(run.scheduled_at, run.completed_at)
  end

  def start_release_text(major: false)
    text = train.automatic? ? "Manually start " : "Start "
    text += major ? "major " : "minor "
    text += "release "
    text + train.next_version(major_only: major)
  end

  def start_upcoming_release_text(major: false)
    text = "Prepare next "
    text += major ? "major " : "minor "
    text += "release "
    text + train.ongoing_release.next_version(major_only: major)
  end
end
