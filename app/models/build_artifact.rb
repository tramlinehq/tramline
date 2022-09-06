class BuildArtifact < ApplicationRecord
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_runs_id, inverse_of: :build_artifact
  has_one :release_situation
  has_one_attached :file

  ZIP_CONTENT_TYPE = "application/zip".freeze

  def save_zip!(io_stream)
    transaction do
      self.file = ActiveStorage::Blob.create_and_upload!(io: io_stream, filename:, content_type: ZIP_CONTENT_TYPE)
      save!
    end
  end

  def filename
    "step-run-#{train_step_runs_id}-release.zip"
  end
end

