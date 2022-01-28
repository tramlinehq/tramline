class Releases::Train::Run < ApplicationRecord
  belongs_to :train, class_name: "Releases::Train"
end
