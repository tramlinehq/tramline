class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail
  encrypts :json_key, deterministic: true

  include Providable

  CHANNELS = {
    production: "production",
    beta: "open testing",
    alpha: "closed testing",
    internal: "internal testing"
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
