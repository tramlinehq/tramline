class SignOff < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :step, class_name: "Releases::Step", foreign_key: "train_step_id"
  belongs_to :user, class_name: "Accounts::User"
  belongs_to :commit, class_name: "Releases::Commit", foreign_key: "releases_commit_id"
end
