# == Schema Information
#
# Table name: train_sign_off_groups
#
#  id                :uuid             not null, primary key
#  train_id          :uuid             not null
#  sign_off_group_id :uuid             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class TrainSignOffGroup < ApplicationRecord
  belongs_to :train, class_name: "Releases::Train"
  belongs_to :sign_off_group
end
