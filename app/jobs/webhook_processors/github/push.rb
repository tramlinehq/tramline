class WebhookProcessors::Github::Push < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Commit

  def perform(train_run_id, commit_attributes)
    @release = Releases::Train::Run.find(train_run_id)
    @commit_attributes = commit_attributes

    transaction do
      commit_record = create_commit
      train.bump_version!(:patch) if release.step_runs.any?
      current_step = release.current_step || 1

      train.steps.where("step_number <= ?", current_step).order(:step_number).each do |step|
        if step.step_number < current_step
          Services::TriggerStepRun.call(step, commit_record, false)
        else
          Services::TriggerStepRun.call(step, commit_record)
        end
      end

      release.update(release_version: train.version_current)
      send_notification!
    end
  end

  private

  attr_reader :release, :commit_attributes

  def create_commit
    params = {
      train:,
      train_run: release,
      commit_hash: commit_attributes[:commit_sha],
      message: commit_message,
      timestamp: commit_attributes[:timestamp],
      author_name: commit_attributes[:author_name],
      author_email: commit_attributes[:author_email],
      url: commit_attributes[:url]
    }

    Releases::Commit.create!(params)
  end

  def send_notification!
    return unless release.commits.size.eql?(1)

    message = "New Release!"
    Notifiers::Slack::ReleaseStarted
      .render_json(train_name: train.name, version_number: train.version_current, branch_name: branch_name, commit_msg: commit_message)
      .then { |notifier| Automatons::Notify.dispatch!(train:, message:, text_block: notifier) }
  end

  def train
    @train ||= @release.train
  end

  def commit_message
    commit_attributes[:message]
  end

  def branch_name
    commit_attributes[:branch_name]
  end
end
