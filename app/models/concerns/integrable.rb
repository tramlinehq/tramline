module Integrable
  extend ActiveSupport::Concern

  included do
    has_many :integrations, as: :integrable, dependent: :destroy
  end

  delegate :ios_store_provider,
    :android_store_provider,
    :slack_build_channel_provider,
    :firebase_build_channel_provider, to: :integrations, allow_nil: true
  delegate :draft_check?, to: :android_store_provider, allow_nil: true

  def firebase_connected?
    integrations.google_firebase_integrations.any?
  end

  def firebase_crashlytics_connected?
    integrations.crashlytics_integrations.any?
  end
end
