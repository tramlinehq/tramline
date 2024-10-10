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

  def bitrise_connected?
    integrations.bitrise_integrations.any?
  end

  def bugsnag_connected?
    integrations.bugsnag_integrations.any?
  end

  def bitbucket_connected?
    integrations.bitbucket_integrations.any?
  end

  def firebase_connected?
    integrations.google_firebase_integrations.any?
  end
end
