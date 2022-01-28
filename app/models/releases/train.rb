class Releases::Train < ApplicationRecord
  extend FriendlyId

  belongs_to :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train
  has_many :steps, class_name: "Releases::Step", inverse_of: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  attribute :repeat_duration, :interval

  def activate!
    update!(status: Releases::Train.statuses[:active])
  end
end
