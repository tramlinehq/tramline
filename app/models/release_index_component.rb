# == Schema Information
#
# Table name: release_index_components
#
#  id               :uuid             not null, primary key
#  name             :string           not null, indexed => [release_index_id]
#  tolerable_range  :numrange         not null
#  tolerable_unit   :string           not null
#  weight           :decimal(4, 3)    not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  release_index_id :uuid             not null, indexed => [name], indexed
#
class ReleaseIndexComponent < ApplicationRecord
  using RefinedArray

  belongs_to :release_index
  enum name: ReleaseIndex::COMPONENTS.keys.map(&:to_s).zip_map_self
  validates :name, uniqueness: {scope: :release_index_id}

  def tolerable?(value)
    tolerable_range.cover?(value)
  end

  def action_score(value)
    if value < tolerable_range.begin; then 1
    elsif tolerable?(value); then 0.5
    else
      0
    end
  end

  def score(value)
    action_score(value) * weight
  end
end
