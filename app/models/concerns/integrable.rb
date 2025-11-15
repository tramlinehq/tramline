module Integrable
  extend ActiveSupport::Concern

  included do
    has_many :integrations, as: :integrable, dependent: :destroy
  end

  def self.find(id)
    ApplicationRecord::INTEGRABLE_TYPES.each do |type|
      record = type.constantize.friendly.find(id)
      return record if record
    rescue ActiveRecord::RecordNotFound
      next
    end

    raise ActiveRecord::RecordNotFound, "Couldn't find integrable with id=#{id}"
  end

  delegate :ios_store_provider,
    :android_store_provider,
    :slack_build_channel_provider,
    :firebase_build_channel_provider, to: :integrations, allow_nil: true
  delegate :draft_check?, to: :android_store_provider, allow_nil: true

  def firebase_connected?
    integrations.connected.google_firebase_integrations.any?
  end

  def firebase_crashlytics_connected?
    integrations.connected.crashlytics_integrations.any?
  end
end
