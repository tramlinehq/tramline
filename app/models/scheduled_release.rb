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

  belongs_to :train
end
