class Releases::Commit < ApplicationRecord
  belongs_to :train
  self.table_name = 'releases_commits'
end
