# frozen_string_literal: true

class V2::ReleaseListComponent < V2::BaseComponent
  include Memery

  def initialize(train:)
    @train = train
  end

  attr_reader :train
  delegate :app, to: :train

  delegate :devops_report, to: :train

  delegate :hotfix_from, to: :train

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

  memoize delegate :ongoing_release, to: :train

  memoize delegate :upcoming_release, to: :train

  memoize delegate :hotfix_release, to: :train

  def ordered_releases
    train.releases.order(scheduled_at: :desc).take(100)
  end

  def release_component(run)
    V2::BaseReleaseComponent.new(run)
  end

  def start_release_text(major: false)
    text = train.automatic? ? "Manually start " : "Start"
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
