# == Schema Information
#
# Table name: google_play_store_integrations
#
#  id                :uuid             not null, primary key
#  json_key          :string
#  original_json_key :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail
  encrypts :json_key, deterministic: true

  include Providable
  include Displayable

  delegate :app, to: :integration

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  CHANNELS = [
    {id: :production, name: "production"},
    {id: :beta, name: "open testing"},
    {id: :alpha, name: "closed testing"},
    {id: :internal, name: "internal testing"}
  ]

  def creatable?
    true
  end

  def connectable?
    false
  end

  def store?
    true
  end

  def to_s
    "google_play_store"
  end

  def channels
    CHANNELS.map(&:with_indifferent_access)
  end

  def correct_key
    errors.add(:json_key, :no_bundles) if developer_api.list_bundles.keys.size < 1
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Errors::BundleIdentifierNotFound, Installations::Errors::GooglePlayDeveloperAPIPermissionDenied
    errors.add(:json_key, :bundle_id_not_found)
  rescue Installations::Errors::GooglePlayDeveloperAPIDisabled
    errors.add(:json_key, :dev_api_not_enabled)
  end

  def developer_api
    Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier, StringIO.new(json_key), +"")
  end
end
