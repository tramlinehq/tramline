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
#  external_id       :string
#
class ExternalRelease < ApplicationRecord
  belongs_to :deployment_run
  delegate :app, :app_store_integration?, to: :deployment_run

  APP_STORE_CONNECT_URL_TEMPLATE =
    Addressable::Template.new("https://appstoreconnect.apple.com/apps/{app_id}/testflight/ios/{external_id}")

  def self.minimum_required
    column_names.map(&:to_sym).filter { |name| name.in? [:name, :status, :build_number, :added_at, :external_id] }
  end

  def store_link
    return unless app_store_integration?
    APP_STORE_CONNECT_URL_TEMPLATE.expand(app_id: app.external_id, external_id:).to_s
  end
end
