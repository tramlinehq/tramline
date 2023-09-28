# == Schema Information
#
# Table name: build_artifacts
#
#  id           :uuid             not null, primary key
#  generated_at :datetime
#  uploaded_at  :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  step_run_id  :uuid             not null, indexed
#
require "zip"

class BuildArtifact < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :step_run, inverse_of: :build_artifact
  has_one_attached :file

  delegate :create_and_upload!, to: ActiveStorage::Blob
  delegate :unzip_artifact?, to: :step_run
  delegate :signed_id, to: :file

  def self.find_by_signed_id(signed_id)
    blob = ActiveStorage::Blob.find_signed(signed_id)
    return nil if blob.blank?
    attachment = ActiveStorage::Attachment.find_by(blob_id: blob.id)
    return nil if attachment.blank?
    find_by(id: attachment.record_id)
  end

  def save_file!(artifact_stream)
    transaction do
      self.file = create_and_upload!(io: artifact_stream.file, filename: gen_filename(artifact_stream.ext))
      self.uploaded_at = Time.current
      save!
    end
  end

  def gen_filename(ext)
    "#{app.slug}-#{step_run.build_version}-build#{ext}"
  end

  def get_filename
    file.blob.filename.to_s
  end

  def with_open
    file.open { |file| yield(file) }
  end

  def download_url
    return if file.nil?

    if Rails.env.development?
      build_url(host: ENV["HOST_NAME"], port: ENV["PORT_NUM"], protocol: "https", disposition: "attachment")
    else
      build_url(protocol: "https", disposition: "attachment")
    end
  end

  def app
    step_run.release_platform.app
  end

  delegate :organization, to: :step_run

  def build_url(params)
    blob_redirect_url(file.signed_id, file.filename, params)
  end
end
