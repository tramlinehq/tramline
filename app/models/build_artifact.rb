# == Schema Information
#
# Table name: build_artifacts
#
#  id              :uuid             not null, primary key
#  generated_at    :datetime
#  storage_service :string           indexed
#  uploaded_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  build_id        :uuid             indexed
#
require "zip"

class BuildArtifact < ApplicationRecord
  include Rails.application.routes.url_helpers

  self.ignored_columns += ["step_run_id"]

  belongs_to :build, inverse_of: :artifact
  has_one_attached :file

  delegate :create_and_upload!, to: ActiveStorage::Blob
  delegate :signed_id, to: :file

  def save_file!(artifact_stream)
    set_storage_service
    service_name = resolve_service_name
    key = filename = gen_filename(artifact_stream.ext)

    transaction do
      self.file = create_and_upload!(io: artifact_stream.file, filename:, key:, service_name:)
      self.uploaded_at = Time.current
      save!
    end
  end

  def gen_filename(ext)
    "#{app.slug}-#{build.version_name}-#{SecureRandom.uuid}-build#{ext}"
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
    build.release_platform_run.app
  end

  delegate :organization, to: :app

  def build_url(params)
    blob_redirect_url(file.signed_id, file.filename, params)
  end

  def file_size_in_mb
    return unless file
    (file.byte_size.to_f / 1.megabyte).round(2)
  end

  private

  def resolve_service_name
    storage_service.present? ? storage_service.to_sym : Rails.application.config.active_storage.service
  end

  # store the storage service per build artifact for ease of migration and point-in-time segregation
  def set_storage_service
    return if storage_service.present?
    custom_svc = organization.custom_storage&.service
    self.storage_service = custom_svc&.present? ? custom_svc : Rails.application.config.active_storage.service.to_s
  end
end
