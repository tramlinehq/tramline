# == Schema Information
#
# Table name: app_variants
#
#  id                      :uuid             not null, primary key
#  bundle_identifier       :string           not null, indexed => [app_config_id]
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  name                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_config_id           :uuid             not null, indexed, indexed => [bundle_identifier]
#
class AppVariant < ApplicationRecord
  has_paper_trail
  include Integrable
  include AppConfigurable

  belongs_to :app_config

  validates :bundle_identifier, presence: true, uniqueness: {scope: :app_config_id}
  validate :duplicate_bundle_identifier
  validate :single_variant_per_app_config, on: :create
  validates :name, presence: true, length: {maximum: 30}

  delegate :app, to: :app_config
  delegate :organization, :active_runs, :platform, to: :app
  delegate :id, to: :app, prefix: true

  def display_text
    "#{name} (#{bundle_identifier})"
  end

  def config = self

  private

  def duplicate_bundle_identifier
    errors.add(:bundle_identifier, :same_as_parent) if app.bundle_identifier == bundle_identifier
  end

  def single_variant_per_app_config
    if AppVariant.exists?(app_config_id: app_config_id)
      errors.add(:app_config_id, "can only have one variant")
    end
  end
end
