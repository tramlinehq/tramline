# == Schema Information
#
# Table name: build_artifacts
#
#  id                 :uuid             not null, primary key
#  generated_at       :datetime
#  uploaded_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  train_step_runs_id :uuid             not null, indexed
#
require "zip"

class BuildArtifact < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_runs_id, inverse_of: :build_artifact
  has_one_attached :file

  delegate :create_and_upload!, to: ActiveStorage::Blob
  delegate :unzip_artifact?, to: :step_run
  delegate :train, to: :step_run
  delegate :app, to: :train

  def save_file!(artifact_stream)
    transaction do
      self.file = create_and_upload!(io: artifact_stream.file, filename: filename(artifact_stream.ext))
      self.uploaded_at = Time.current
      save!
    end
  end

  def filename(ext)
    "#{app.slug}-#{step_run.build_version}-build#{ext}"
  end

  def with_open
    file.open { |file| yield(file) }
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
