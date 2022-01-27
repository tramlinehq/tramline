class Releases::Train < ApplicationRecord
  self.table_name = :release_trains

  belongs_to :app
  has_many :runs, class_name: "Releases::Train::Run"
  has_many :steps, class_name: "Releases::Step", foreign_key: :release_train_id

  attribute :repeat_duration, :interval
end
