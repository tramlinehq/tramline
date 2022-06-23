class Releases::CommitListner < ApplicationRecord
  self.table_name = 'releases_commit_listners'

  belongs_to :train, class_name: 'Releases::Train'
end
