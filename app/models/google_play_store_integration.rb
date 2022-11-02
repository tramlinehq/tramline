# == Schema Information
#
# Table name: google_play_store_integrations
#
#  id                :uuid             not null, primary key
#  json_key          :string
#  original_json_key :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
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

  def store?
    true
  end

  def to_s
    "google_play_store"
  end

  def channels
    CHANNELS.invert.map { |k, v| [k, {k => v}.to_json] }
  end
end
