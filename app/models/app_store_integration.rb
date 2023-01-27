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

  def access_key
    StringIO.new(p8_key_file)
  end

  def installation
    # Installations::Apple::AppStoreConnect::Api.new(app.bundle_identifier, access_key)
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

  def to_s
    "app_store"
  end

  def correct_key
    # validate app id
    true
  end
end
