# == Schema Information
#
# Table name: custom_storages
#
#  id              :bigint           not null, primary key
#  bucket          :string           not null
#  bucket_region   :string           not null
#  service         :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null, indexed
#
class Accounts::CustomStorage < ApplicationRecord
  belongs_to :organization, class_name: "Accounts::Organization"

  validates :bucket, presence: true
  validates :bucket_region, presence: true
  validates :service, presence: true

  SERVICES = {
    s3: "Amazon S3",
    google: "Google Cloud Storage",
    google_india: "Google Cloud Storage",
  }

  def service_name
    SERVICES[service.to_sym]
  end
end
