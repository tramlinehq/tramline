class BuildArtifact < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_runs_id, inverse_of: :build_artifact
  has_one :release_situation
  has_one_attached :file

  ZIP_CONTENT_TYPE = "application/zip".freeze

  def save_zip!(io_stream)
    transaction do
      self.file = ActiveStorage::Blob.create_and_upload!(io: io_stream, filename:, content_type: ZIP_CONTENT_TYPE)
      self.uploaded_at = Time.current
      save!
    end
  end

  def filename
    "step-run-#{train_step_runs_id}-release.zip"
  end

  def download_url
    if Rails.env.development?
      rails_blob_url(file, host: ENV["HOST_NAME"], port: ENV["PORT_NUM"], protocol: "https", disposition: "attachment")
    else
      rails_blob_url(file, protocol: "https", disposition: "attachment")
    end
  end
end
