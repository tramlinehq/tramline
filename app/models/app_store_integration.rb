# == Schema Information
#
# Table name: app_store_integrations
#
#  id         :uuid             not null, primary key
#  p8_key     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  issuer_id  :string
#  key_id     :string
#
class AppStoreIntegration < ApplicationRecord
  has_paper_trail

  encrypts :key_id, deterministic: true
  encrypts :p8_key, deterministic: true
  encrypts :issuer_id, deterministic: true

  include Providable
  include Displayable
  include Loggable

  delegate :app, to: :integration

  validate :correct_key, on: :create

  attr_accessor :p8_key_file

  CHANNELS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  def access_key
    OpenSSL::PKey::EC.new(p8_key)
  end

  def installation
    Installations::Apple::AppStoreConnect::Api.new(app.bundle_identifier, key_id, issuer_id, access_key)
  end

  def creatable?
    true
  end

  def connectable?
    false
  end

  def store?
    true
  end

  delegate :find_build, :find_app, to: :installation
  def promote_to_testflight(beta_group_id, build_number)
    installation.add_build_to_group(beta_group_id, build_number)
  end

  def build_channels
    installation.external_groups(CHANNELS_TRANSFORMATIONS).map { |channel| channel.slice(:id, :name) }
  end

  def to_s
    "app_store"
  end

  def correct_key
    errors.add(:key_id, :no_app_found) if find_app.blank?
  end
end
