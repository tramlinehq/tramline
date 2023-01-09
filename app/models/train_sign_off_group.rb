# == Schema Information
#
# Table name: train_sign_off_groups
#
#  id                :uuid             not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  sign_off_group_id :uuid             not null, indexed
#  train_id          :uuid             not null, indexed
#
class TrainSignOffGroup < ApplicationRecord
  belongs_to :train, class_name: "Releases::Train"
  belongs_to :sign_off_group
end
