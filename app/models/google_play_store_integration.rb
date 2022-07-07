class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail

  has_one :integration, as: :providable, dependent: :destroy

  encrypts :json_key, deterministic: true

  def creatable?
    true
  end

  def connectable?
    false
  end

  def to_s
    "google_play_store"
  end
end
