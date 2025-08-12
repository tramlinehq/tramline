# == Schema Information
#
# Table name: accounts_custom_storages
#
#  id              :uuid             not null, primary key
#  bucket          :string           not null
#  credentials     :jsonb            not null
#  project_id      :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null, indexed
#
class Accounts::CustomStorage < ApplicationRecord
  belongs_to :organization, class_name: "Accounts::Organization"

  validates :bucket, presence: true
  validates :project_id, presence: true
  validates :credentials, presence: true
  validate :credentials_must_be_a_hash

  private

  def credentials_must_be_a_hash
    errors.add(:credentials, "must be a valid JSON object") unless credentials.is_a?(Hash)
  end
end
