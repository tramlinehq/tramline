# == Schema Information
#
# Table name: commit_listeners
#
#  id                  :uuid             not null, primary key
#  branch_name         :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_platform_id :uuid             indexed
#  train_id            :uuid
#
class CommitListener < ApplicationRecord
  belongs_to :train, inverse_of: :commit_listeners
end
