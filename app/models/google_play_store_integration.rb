class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail

  has_one :integration

  encrypts :json_key, deterministic: true

  def to_s
    "google_play_store"
  end
end
