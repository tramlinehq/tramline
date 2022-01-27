class Releases::Train::Run < ApplicationRecord
  self.table_name = :release_train_runs
  belongs_to :train, class_name: "Releases::Train"
end
