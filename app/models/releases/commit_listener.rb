# == Schema Information
#
# Table name: releases_commit_listeners
#
#  id          :uuid             not null, primary key
#  train_id    :uuid             not null
#  branch_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Releases::CommitListener < ApplicationRecord
  self.table_name = "releases_commit_listeners"
  belongs_to :train, class_name: "Releases::Train"
end
