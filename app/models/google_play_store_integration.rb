class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail

  has_one :integration, as: :providable, dependent: :destroy

  encrypts :json_key, deterministic: true

  CHANNELS = {
    production: "production",
    open_testing: "open testing",
    closed_testing: "closed testing",
    internal_testing: "internal testing"
  }

  def creatable?
    true
  end

  def connectable?
    false
  end

  def to_s
    "google_play_store"
  end

  def channels
    CHANNELS.invert.map { |k, v| [k, {k => v}.to_json] }
  end
end
