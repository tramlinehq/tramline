# == Schema Information
#
# Table name: external_apps
#
#  id           :uuid             not null, primary key
#  channel_data :jsonb
#  fetched_at   :datetime         indexed
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  app_id       :uuid             not null, indexed
#

class ExternalApp < ApplicationRecord
  has_paper_trail

  belongs_to :app

  CHANNEL_DATA_SCHEMA = Rails.root.join("config/schema/external_app_channel_data.json")

  validates :channel_data, presence: true, json: {message: ->(errors) { errors }, schema: CHANNEL_DATA_SCHEMA}
end
