class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail

  has_one :integration, as: :providable

  encrypts :json_key, deterministic: true

  def complete_access
    # do nothing
  end

  def to_s
    "google_play_store"
  end
end
