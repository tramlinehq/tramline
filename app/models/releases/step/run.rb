class Releases::Step::Run < ApplicationRecord
  self.table_name = :release_train_step_runs

  belongs_to :step, class_name: "Releases::Step"
  belongs_to :train, class_name: "Releases::Train"
end
