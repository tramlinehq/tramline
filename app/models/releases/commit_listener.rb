# == Schema Information
#
# Table name: releases_commit_listeners
#
#  id          :uuid             not null, primary key
#  branch_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  train_id    :uuid             not null, indexed
#
class Releases::CommitListener < ApplicationRecord
  self.table_name = "releases_commit_listeners"
  belongs_to :train, class_name: "Releases::Train"
end
