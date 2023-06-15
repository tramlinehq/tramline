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

  GOOGLE_PLAY_STORE_URL_TEMPLATE =
    Addressable::Template.new("https://play.google.com/store/apps/details{?query*}")
  APP_STORE_URL_TEMPLATE =
    Addressable::Template.new("https://apps.apple.com/app/ueno/id{id}")

  belongs_to :organization, class_name: "Accounts::Organization", optional: false
  has_one :config, class_name: "AppConfig", dependent: :destroy
  has_many :external_apps, inverse_of: :app, dependent: :destroy
  has_many :integrations, inverse_of: :app, dependent: :destroy

  has_many :trains, dependent: :destroy
  has_many :releases, through: :trains

  has_many :release_platforms, dependent: :destroy
  has_many :release_platform_runs, through: :releases
  has_many :steps, through: :release_platforms

  validate :no_trains_are_running, on: :update
  validates :bundle_identifier, uniqueness: {scope: [:platform, :organization_id]}
  validates :build_number, numericality: {greater_than_or_equal_to: :build_number_was}, on: :update
  validates :build_number, numericality: {less_than: 2100000000}, if: -> { android? }

  enum platform: {android: "android", ios: "ios", cross_platform: "cross_platform"}

  after_initialize :initialize_config, if: :new_record?
  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true

  delegate :vcs_provider,
    :ci_cd_provider,
    :notification_provider,
    :store_provider,
    :ios_store_provider,
    :android_store_provider,
    :slack_build_channel_provider,
    :slack_notifications?, to: :integrations, allow_nil: true

  scope :with_trains, -> { joins(:trains).distinct }

  def self.allowed_platforms(_)
    {
      android: "Android",
      ios: "iOS",
      cross_platform: "Cross Platform"
    }.invert
  end

  def active_runs
    releases.on_track
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
    elsif ios?
      APP_STORE_URL_TEMPLATE.expand(id: external_id).to_s
    else
      "google.com" # FIXME
    end
  end

  def send_notifications?
    notifications_set_up? && config.notification_channel.present?
  end

  def notifications_set_up?
    notification_provider.present?
  end

  # this helps power initial setup instructions after an app is created
  def app_setup_instructions
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

  def train_setup_instructions
    train_setup = {
      train: {
        visible: !trains.any?, completed: trains.any?
      }
    }

    ios_steps_setup =
      {
        ios_review_step: {
          visible: trains.any?, completed: trains.first&.release_platforms&.ios&.first&.steps&.review&.any?
        },
        ios_release_step: {
          visible: trains.any?, completed: trains.first&.release_platforms&.ios&.first&.steps&.release&.any?
        }
      }

    android_steps_setup =
      {
        android_review_step: {
          visible: trains.any?, completed: trains.first&.release_platforms&.android&.first&.steps&.review&.any?
        },
        android_release_step: {
          visible: trains.any?, completed: trains.first&.release_platforms&.android&.first&.steps&.release&.any?
        }
      }

    instructions = if cross_platform?
      [train_setup, ios_steps_setup, android_steps_setup]
    elsif android?
      [train_setup, android_steps_setup]
    else
      [train_setup, ios_steps_setup]
    end

    instructions.flatten.reduce(:merge)
  end

  # FIXME: this is probably quite inefficient for a lot of apps/trains
  def high_level_overview
    release_platforms.only_with_runs.index_with do |release_platform|
      {
        in_review: release_platform.runs.on_track.first,
        last_released: release_platform.runs.released.order("completed_at DESC").first
      }
    end
  end

  def set_external_details(external_id)
    update(external_id: external_id)
  end

  def has_store_integration?
    integrations.any?(&:store?)
  end

  def create_external!
    return unless has_store_integration?

    if cross_platform?
      update_external_app(:android, android_store_provider)
      update_external_app(:ios, ios_store_provider)
    elsif android?
      update_external_app(:android, android_store_provider)
    else
      update_external_app(:ios, ios_store_provider)
    end
  end

  def update_external_app(platform, provider)
    external_app_data = provider.channel_data

    if latest_external_app&.channel_data != external_app_data
      external_apps.create!(channel_data: external_app_data, fetched_at: Time.current, platform:)
    end
  end

  def latest_external_app
    external_apps.order(fetched_at: :desc).first
  end

  def latest_external_apps
    {android: external_apps.where(platform: "android").order(fetched_at: :desc).first,
     ios: external_apps.where(platform: "ios").order(fetched_at: :desc).first}
  end

  def refresh_external_app
    RefreshExternalAppJob.perform_later(id)
  end

  private

  def initialize_config
    build_config
  end

  def no_trains_are_running
    if release_platforms.running? && bundle_identifier_changed?
      errors.add(:bundle_identifier, "cannot be updated if there are running trains!")
    end
  end

  def ensure_deletable
    errors.add(:trains, "cannot delete an app if there are any releases made from it!") if releases.present?
  end
end
