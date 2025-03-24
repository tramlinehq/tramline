# == Schema Information
#
# Table name: steps
#
#  id                     :uuid             not null, primary key
#  name                   :string           not null
#  description            :string           not null
#  status                 :string           not null
#  step_number            :integer          default(0), not null
#  run_after_duration     :interval          not null
#  ci_cd_channel          :json             not null
#  build_artifact_channel :json             not null
#  slug                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  train_id               :uuid             not null, indexed
#
# Indexes
#
#  index_train_steps_on_step_number_and_train_id  (step_number, train_id) UNIQUE
#  index_train_steps_on_train_id                  (train_id)
#

class Steps < ApplicationRecord
  belongs_to :train

  validates :name, :description, :status, :step_number, :run_after_duration, :ci_cd_channel, :build_artifact_channel, presence: true
  validates :step_number, numericality: {only_integer: true}

  # Define the status enum if necessary
  enum :status, {pending: "pending", running: "running", completed: "completed", stopped: "stopped"}

  def formatted_status
    status.capitalize
  end
end
