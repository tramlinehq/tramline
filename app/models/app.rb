# == Schema Information
#
# Table name: apps
#
#  id                :uuid             not null, primary key
#  build_number      :bigint           not null
#  bundle_identifier :string           not null, indexed => [platform, organization_id]
#  description       :string
#  name              :string           not null
#  platform          :string           not null, indexed => [bundle_identifier, organization_id]
#  slug              :string
#  timezone          :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  external_id       :string
#  organization_id   :uuid             not null, indexed, indexed => [platform, bundle_identifier]
#
class App < ApplicationRecord
  has_paper_trail
  extend FriendlyId
  include Flipper::Identifier

  GOOGLE_PLAY_STORE_URL_TEMPLATE =
    Addressable::Template.new("https://play.google.com/store/apps/details{?query*}")
  APP_STORE_URL_TEMPLATE =
    Addressable::Template.new("https://apps.apple.com/app/ueno/id{id}")

  belongs_to :organization, class_name: "Accounts::Organization", optional: false
  has_one :config, class_name: "AppConfig", dependent: :destroy
  has_many :external_apps, inverse_of: :app, dependent: :destroy
  has_many :integrations, inverse_of: :app, dependent: :destroy
  has_many :trains, class_name: "Releases::Train", dependent: :destroy
  has_many :train_runs, through: :trains
  has_many :sign_off_groups, dependent: :destroy

  validate :no_trains_are_running, on: :update
  validates :bundle_identifier, uniqueness: {scope: [:platform, :organization_id]}
  validates :build_number, numericality: {greater_than_or_equal_to: :build_number_was}, on: :update
  validates :build_number, numericality: {less_than: 2100000000}, if: -> { android? }

  enum platform: {android: "android", ios: "ios"}

  accepts_nested_attributes_for :sign_off_groups, allow_destroy: true, reject_if: :reject_sign_off_groups?

  after_initialize :initialize_config, if: :new_record?
  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true

  delegate :vcs_provider, :ci_cd_provider, :notification_provider, :store_provider, to: :integrations, allow_nil: true

  scope :with_trains, -> { joins(:trains).distinct }

  def all_builds(column: nil, direction: nil)
    Queries::AllBuilds.call(app: self, column:, direction:)
  end

  def runs
    Releases::Train::Run.joins(train: :app).where(train: {app: self})
  end

  def self.allowed_platforms(current_user)
    if Flipper.enabled?(:ios_apps_allowed, current_user)
      {
        android: "Android",
        ios: "iOS"
      }.invert
    else
      {
        android: "Android"
      }.invert
    end
  end

  def active_runs
    runs.on_track
  end

  def ready?
    integrations.ready? and config&.ready?
  end

  def bump_build_number!
    with_lock do
      self.build_number = build_number.succ
      save!
      build_number.to_s
    end
  end

  def store_link
    if android?
      GOOGLE_PLAY_STORE_URL_TEMPLATE.expand(query: {id: bundle_identifier}).to_s
    else
      APP_STORE_URL_TEMPLATE.expand(id: external_id).to_s
    end
  end

  def send_notifications?
    notifications_set_up? && config.notification_channel.present?
  end

  def notifications_set_up?
    notification_provider.present?
  end

  # this helps power initial setup instructions after an app is created
  def setup_instructions
    app_setup = {
      app: {
        visible: persisted?, completed: persisted?
      }
    }

    integration_setup =
      Integration::MINIMUM_REQUIRED_SET.map do |integration_category|
        is_completed = integrations.any? { |i| i.category.eql?(integration_category.to_s) }
        {
          integration_category => {
            visible: true, completed: is_completed
          }
        }
      end

    app_config_setup = {
      app_config: {
        visible: integrations.ready?, completed: ready?
      }
    }

    [app_setup, integration_setup, app_config_setup]
      .flatten
      .reduce(:merge)
  end

  def sign_offs_enabled?
    Flipper.enabled?(:sign_offs, self)
  end

  def set_external_details(external_id)
    update(external_id: external_id)
  end

  def has_store_integration?
    integrations.any?(&:store?)
  end

  def create_external!
    return unless has_store_integration?
    external_app_data = store_provider.channel_data

    if latest_external_app&.channel_data != external_app_data
      external_apps.create!(channel_data: external_app_data, fetched_at: Time.current)
    end
  end

  def latest_external_app
    external_apps.order(fetched_at: :desc).first
  end

  def refresh_external_app
    RefreshExternalAppJob.perform_later(id)
  end

  private

  def initialize_config
    build_config
  end

  def no_trains_are_running
    if trains.running? && bundle_identifier_changed?
      errors.add(:bundle_identifier, "cannot be updated if there are running trains!")
    end
  end

  def reject_sign_off_groups?(attributes)
    attributes["name"].blank? || attributes["member_ids"].compact_blank.empty?
  end

  def ensure_deletable
    errors.add(:trains, "cannot delete an app if there are any releases made from it!") if runs.present?
  end
end
