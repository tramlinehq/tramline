class V2::ScheduledTrainComponent < V2::BaseComponent
  def initialize(train:)
    @train = train
    @ongoing_release = train.ongoing_release
    @past_releases = train.scheduled_releases.where("scheduled_at < ?", Time.current.beginning_of_day).order(scheduled_at: :asc).last(2)
    @future_release = train.scheduled_releases.pending.order(scheduled_at: :asc).first
  end

  attr_reader :ongoing_release, :past_releases, :future_release, :train

  def status(scheduled_release)
    return unless scheduled_release
    return {text: "Pending", status: :routine} if scheduled_release.pending?
    return {text: "Success", status: :success} if scheduled_release.is_success
    {text: "Skipped", status: :neutral}
  end

  def time_text(scheduled_release)
    return unless scheduled_release
    return "Scheduled for #{time_format(scheduled_release.scheduled_at, only_time: true)}" if scheduled_release.scheduled_at.past?
    return "Scheduled for #{time_format(scheduled_release.scheduled_at, only_time: true)}" if scheduled_release.scheduled_at.future?
    "Running"
  end

  def ongoing_text
    return unless ongoing_release
    "Kickoff at #{time_format(ongoing_release.scheduled_at, only_time: true)}"
  end

  def past_text(past_release)
    return unless past_release
    return "Was scheduled for #{time_format(past_release.scheduled_at, only_time: true)}" unless past_release.is_success?
    "Ran at #{time_format(past_release.scheduled_at, only_time: true)}"
  end

  def past_title(past_release)
    return unless past_release
    past_release.release&.release_version
  end

  def next_run_at
    return unless future_release
    future_release.scheduled_at + train.repeat_duration
  end
end
