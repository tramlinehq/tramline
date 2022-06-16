class TrainSignOffGroup < ApplicationRecord
  belongs_to :train, class_name: 'Releases::Train'
  belongs_to :sign_off_group
end
