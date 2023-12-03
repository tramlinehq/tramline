# == Schema Information
#
# Table name: app_variants
#
#  id                      :uuid             not null, primary key
#  bundle_identifier       :string           not null, indexed => [app_config_id]
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_config_id           :uuid             not null, indexed, indexed => [bundle_identifier]
#
class AppVariant < ApplicationRecord
  has_paper_trail

  belongs_to :app_config

  validates :bundle_identifier, presence: true, uniqueness: { scope: :app_config_id }
  validate :duplicate_bundle_identifier, on: :create

  delegate :app, to: :app_config

  private

  def duplicate_bundle_identifier
    errors.add(:bundle_identifier, :same_as_parent) if app.bundle_identifier == bundle_identifier
  end
end
