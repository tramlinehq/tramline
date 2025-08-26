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

  SERVICES = {
    google: "Google Cloud Storage",
    google_india: "Google Cloud Storage"
  }

  validates :bucket, presence: true
  validates :bucket_region, presence: true
  validates :service, presence: true, inclusion: {in: SERVICES.keys.map(&:to_s)}
  validates :organization, uniqueness: true

  before_validation :normalize_service!

  def service_name
    SERVICES[service.to_sym]
  end

  private

  def normalize_service!
    self.service = service.to_s.strip.downcase
  end
end
