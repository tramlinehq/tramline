# == Schema Information
#
# Table name: external_builds
#
#  id                :uuid             not null, primary key
#  added_at          :datetime
#  build_number      :string
#  name              :string
#  size_in_bytes     :integer
#  status            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  deployment_run_id :uuid             not null, indexed
#
class ExternalBuild < ApplicationRecord
  belongs_to :deployment_run

  def self.minimum_required
    column_names.map(&:to_sym).filter { |name| name.in? [:name, :status, :build_number, :added_at] }
  end
end
