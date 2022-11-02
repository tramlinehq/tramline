# == Schema Information
#
# Table name: build_artifacts
#
#  id                 :uuid             not null, primary key
#  train_step_runs_id :uuid             not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  generated_at       :datetime
#  uploaded_at        :datetime
#
require "zip"

class BuildArtifact < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_runs_id, inverse_of: :build_artifact
  has_one :release_situation
  has_one_attached :file

  delegate :unzip_artifact?, to: :step_run
  delegate :train, to: :step_run
  delegate :app, to: :train

  VALID_UNZIPS = "*.{aab,apk,txt}".freeze

  def save_file!(io_stream)
    transaction do
      self.file = ActiveStorage::Blob.create_and_upload!(io: io_stream, filename:, content_type: io_stream.content_type, identify: false)
      self.uploaded_at = Time.current
      save!
    end
  end

  def filename
    "#{app.slug}-#{step_run.build_version}-build"
  end

  def file_for_playstore_upload
    file.open do |temp_file|
      # FIXME: This is an expensive operation, we should not be unzipping here but before pushing to object store
      artifact_file =
        if unzip_artifact?
          Zip::File.open(temp_file).glob(VALID_UNZIPS).first
        else
          return yield(temp_file)
        end

      Tempfile.open(%w[artifact .aab]) do |new_temp_file|
        artifact_file.extract(new_temp_file.path) { true }
        yield(new_temp_file)
      end
    end
  end

  def download_url
    return if file.nil?

    if Rails.env.development?
      rails_blob_url(file, host: ENV["HOST_NAME"], port: ENV["PORT_NUM"], protocol: "https", disposition: "attachment")
    else
      rails_blob_url(file, protocol: "https", disposition: "attachment")
    end
  end
end
