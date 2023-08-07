# == Schema Information
#
# Table name: scheduled_releases
#
#  id             :uuid             not null, primary key
#  failure_reason :string
#  is_success     :boolean          default(FALSE)
#  scheduled_at   :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  train_id       :uuid             not null, indexed
#
class ScheduledRelease < ApplicationRecord
  has_paper_trail

  self.implicit_order_column = :scheduled_at

  belongs_to :train

  scope :pending, -> { where("scheduled_at > ?", Time.current) }

  after_create_commit :schedule_kickoff!

  def schedule_kickoff!
    TrainKickoffJob.set(wait_until: scheduled_at).perform_later(id)
    Rails.logger.info "Release scheduled for #{train.name} at #{scheduled_at}"
    # TODO: notify the user
  end
end
