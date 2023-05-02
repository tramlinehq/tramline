# == Schema Information
#
# Table name: external_releases
#
#  id                :uuid             not null, primary key
#  added_at          :datetime
#  build_number      :string
#  external_link     :string
#  name              :string
#  released_at       :datetime
#  reviewed_at       :datetime
#  size_in_bytes     :integer
#  status            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  deployment_run_id :uuid             not null, indexed
#  external_id       :string
#
class ExternalRelease < ApplicationRecord
  belongs_to :deployment_run
  delegate :app, :app_store_integration?, to: :deployment_run

  def self.minimum_required
    column_names.map(&:to_sym).filter { |name| name.in? [:name, :status, :build_number, :external_id, :added_at] }
  end
end
