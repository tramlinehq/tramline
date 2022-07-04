class Releases::Commit < ApplicationRecord
  self.table_name = "releases_commits"

  belongs_to :train
  belongs_to :train_run, class_name: "Releases::Train::Run"
end
