class Releases::Commit < ApplicationRecord
  belongs_to :train
  belongs_to :train_run, class_name: 'Releases::Train::Run'
  self.table_name = 'releases_commits'
end
