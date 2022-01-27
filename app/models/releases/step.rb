class Releases::Step < ApplicationRecord
  self.table_name = :release_train_steps
  belongs_to :train, class_name: "Releases::Train", foreign_key: :release_train_id
end
