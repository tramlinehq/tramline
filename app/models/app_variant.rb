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
  include PlatformAwareness

  belongs_to :app_config
  has_many :steps, dependent: :nullify

  validates :bundle_identifier, presence: true, uniqueness: {scope: :app_config_id}
  validate :duplicate_bundle_identifier, on: :create

  delegate :app, to: :app_config
  delegate :organization, :active_runs, to: :app
  delegate :id, to: :app, prefix: true

  def display_text
    "#{name} (#{bundle_identifier})"
  end

  private

  def duplicate_bundle_identifier
    errors.add(:bundle_identifier, :same_as_parent) if app.bundle_identifier == bundle_identifier
  end
end
