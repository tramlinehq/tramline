# == Schema Information
#
# Table name: app_variants
#
#  id                      :uuid             not null, primary key
#  bundle_identifier       :string           not null, indexed => [app_config_id], indexed => [app_id]
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  name                    :string           not null
#  slug                    :string           indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_config_id           :uuid             indexed, indexed => [bundle_identifier]
#  app_id                  :uuid             indexed, indexed => [bundle_identifier]
#
class AppVariant < ApplicationRecord
  has_paper_trail
  extend FriendlyId
  include Integrable

  # self.ignored_columns += %w[firebase_android_config firebase_ios_config]

  # belongs_to :app_config, optional: true # TODO: remove this
  belongs_to :app

  validates :bundle_identifier, presence: true, uniqueness: {scope: :app_id}
  validate :duplicate_bundle_identifier
  validates :name, presence: true, length: {maximum: 30}

  friendly_id :slug_candidates, use: :slugged
  normalizes :name, with: ->(name) { name.squish }

  delegate :organization, :active_runs, :platform, to: :app
  delegate :id, to: :app, prefix: true

  def slug_candidates
    [
      [:name, :bundle_identifier],
      [:name, :bundle_identifier, :id]
    ]
  end

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
end
