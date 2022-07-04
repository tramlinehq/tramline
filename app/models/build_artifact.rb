class BuildArtifact < ApplicationRecord
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_runs_id
  has_one_attached :file
end
