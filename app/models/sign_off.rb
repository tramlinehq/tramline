# == Schema Information
#
# Table name: sign_offs
#
#  id                 :uuid             not null, primary key
#  signed             :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  releases_commit_id :uuid             not null, indexed => [train_step_id, sign_off_group_id], indexed
#  sign_off_group_id  :uuid             not null, indexed => [releases_commit_id, train_step_id], indexed
#  train_step_id      :uuid             not null, indexed => [releases_commit_id, sign_off_group_id], indexed
#  user_id            :uuid             not null, indexed
#
class SignOff < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :user, class_name: "Accounts::User"
  belongs_to :step, class_name: "Releases::Step", foreign_key: "train_step_id", inverse_of: :sign_offs
  belongs_to :commit, class_name: "Releases::Commit", foreign_key: "releases_commit_id", inverse_of: :sign_offs

  validates :releases_commit_id, uniqueness: {scope: [:train_step_id, :sign_off_group_id]}

  after_update :reset_approval!
  before_destroy :reset_approval!

  def step_run
    commit.step_runs.find_by(step: step)
  end

  def reset_approval!
    step_run&.reset_approval!
  end
end
