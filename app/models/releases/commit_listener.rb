class Releases::CommitListener < ApplicationRecord
  self.table_name = 'releases_commit_listeners'

  belongs_to :train, class_name: 'Releases::Train'
end
