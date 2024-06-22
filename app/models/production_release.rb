# == Schema Information
#
# Table name: production_releases
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  build_id   :uuid             not null, indexed
#
class ProductionRelease < ApplicationRecord
  include Loggable

  belongs_to :build
  has_one :store_submission
  has_many :release_health_events, dependent: :destroy, inverse_of: :production_release
  has_many :release_health_metrics, dependent: :destroy, inverse_of: :production_release
end
