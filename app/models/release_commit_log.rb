# == Schema Information
#
# Table name: release_commit_logs
#
#  id           :uuid             not null, primary key
#  commits      :jsonb
#  from         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  train_run_id :uuid             not null, indexed
#
class ReleaseCommitLog < ApplicationRecord
  has_paper_trail

  belongs_to :train_run, class_name: "Releases::Train::Run"
end
