# == Schema Information
#
# Table name: custom_storages
#
#  id              :bigint           not null, primary key
#  bucket          :string           not null
#  credentials     :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null, indexed
#  project_id      :string           not null
#
class Accounts::CustomStorage < ApplicationRecord
  belongs_to :organization, class_name: "Accounts::Organization"

  validates :bucket, presence: true
  validates :project_id, presence: true
  validates :credentials, presence: true
  validate :credentials_must_be_a_hash

  encrypts :credentials, deterministic: true

  private

  def credentials_must_be_a_hash
    errors.add(:credentials, "must be a valid JSON object") unless credentials.is_a?(Hash)
  end
end
