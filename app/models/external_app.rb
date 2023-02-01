# == Schema Information
#
# Table name: external_apps
#
#  id           :uuid             not null, primary key
#  channel_data :json
#  fetched_at   :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  app_id       :uuid             not null, indexed
#
class ExternalApp < ApplicationRecord
  has_paper_trail

  belongs_to :app

  def channels
    channel_data.map { |ch| ch.with_indifferent_access }
  end
end
