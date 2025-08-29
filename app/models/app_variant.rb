# == Schema Information
#
# Table name: app_variants
#
#  id                      :uuid             not null, primary key
#  bundle_identifier       :string           not null, indexed => [app_id]
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  name                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_id                  :uuid             not null, indexed, indexed => [bundle_identifier]
#
class AppVariant < ApplicationRecord
  has_paper_trail
  include Integrable

  belongs_to :app

  validates :bundle_identifier, presence: true, uniqueness: {scope: :app_id}
  validate :duplicate_bundle_identifier
  validate :single_variant_per_app, on: :create
  validates :name, presence: true, length: {maximum: 30}

  delegate :organization, :active_runs, :platform, to: :app
  delegate :id, to: :app, prefix: true

  def display_text
    "#{name} (#{bundle_identifier})"
  end

  def config = self

  def disconnect!(_)
    raise NotImplementedError
  end

  private

  def duplicate_bundle_identifier
    errors.add(:bundle_identifier, :same_as_parent) if app.bundle_identifier == bundle_identifier
  end

  def single_variant_per_app
    if AppVariant.exists?(app_id: app_id)
      errors.add(:app_id, "can only have one variant")
    end
  end
end
