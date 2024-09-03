# == Schema Information
#
# Table name: apps
#
#  id                :uuid             not null, primary key
#  build_number      :bigint           not null
#  bundle_identifier :string           not null, indexed => [platform, organization_id]
#  description       :string
#  draft             :boolean
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
  include Displayable
  extend FriendlyId

  GOOGLE_PLAY_STORE_URL_TEMPLATE = Addressable::Template.new("https://play.google.com/store/apps/details{?query*}")
  APP_STORE_URL_TEMPLATE = Addressable::Template.new("https://apps.apple.com/app/ueno/id{id}")
  PUBLIC_ANDROID_ICON = "https://storage.googleapis.com/tramline-public-assets/default_android.png"
  PUBLIC_IOS_ICON = "https://storage.googleapis.com/tramline-public-assets/default_ios.png"

  belongs_to :organization, class_name: "Accounts::Organization", optional: false
  has_one :config, class_name: "AppConfig", dependent: :destroy
  has_many :variants, through: :config
  has_many :external_apps, inverse_of: :app, dependent: :destroy
  has_many :integrations, inverse_of: :app, dependent: :destroy
  has_many :trains, -> { sequential }, dependent: :destroy, inverse_of: :app
  has_many :releases, through: :trains
  has_many :step_runs, through: :releases
  has_many :deployment_runs, through: :releases
  has_many :release_platforms, dependent: :destroy
  has_many :release_platform_runs, through: :releases
  has_many :steps, through: :release_platforms

  validate :no_trains_are_running, on: :update
  validates :bundle_identifier, uniqueness: {scope: [:platform, :organization_id]}
  validates :build_number, numericality: {greater_than_or_equal_to: :build_number_was}, on: :update
  validates :build_number, numericality: {less_than: 2100000000}

  enum :platform, {android: "android", ios: "ios", cross_platform: "cross_platform"}

  after_initialize :initialize_config, if: :new_record?
  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  friendly_id :name, use: :slugged
  normalizes :name, with: ->(name) { name.squish }

  delegate :vcs_provider,
    :ci_cd_provider,
    :monitoring_provider,
    :notification_provider,
    :ios_store_provider,
    :android_store_provider,
    :slack_build_channel_provider,
    :firebase_build_channel_provider,
    :slack_notifications?, to: :integrations, allow_nil: true
  delegate :draft_check?, to: :android_store_provider, allow_nil: true

  scope :with_trains, -> { joins(:trains).distinct }
  scope :sequential, -> { reorder("apps.created_at ASC") }

  def self.allowed_platforms
    {
      android: "Android",
      ios: "iOS",
      cross_platform: "Cross Platform"
    }.invert
  end

  def has_recent_activity?
    return true if created_at > 3.months.ago
    return false if releases.none?
    releases.first.scheduled_at > 3.months.ago
  end

  def deploy_action_enabled?
    Flipper.enabled?(:deploy_action_enabled, self)
  end

  def variant_options
    opts = {"Default (#{bundle_identifier})" => nil}
    opts.merge variants.map.to_h { |v| [v.display_text, v.id] }
  end

  def active_runs
    releases.pending_release
  end

  def ready?
    integrations.ready? and config&.ready?
  end

  def guided_train_setup?
    trains.none? || train_in_creation&.in_creation?
  end

  def train_in_creation
    trains.first if trains.size == 1
  end

  def latest_store_step_runs
    deployment_runs
      .reached_production
      .group_by(&:platform)
      .to_h { |platform, runs| [platform, runs.max_by(&:updated_at)&.step_run] }
      .values
  end

  # NOTE: fetches and uses latest build numbers from the stores, if added,
  # to reduce build upload rejection probability
  def bump_build_number!
    store_build_number = latest_store_build_number
    with_lock do
      self.build_number = [store_build_number, build_number].compact.max.succ
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

  def notifications_set_up?
    notification_provider.present?
  end

  def bitrise_connected?
    integrations.bitrise_integrations.any?
  end

  def bugsnag_connected?
    integrations.bugsnag_integrations.any?
  end

  def firebase_connected?
    integrations.google_firebase_integrations.any?
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
        is_completed = integrations.category_ready?(integration_category)
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
        ios_release_step: {
          visible: trains.any?, completed: trains.ios_release_steps?
        }
      }

    android_steps_setup =
      {
        android_release_step: {
          visible: trains.any?, completed: trains.android_release_steps?
        }
      }

    instructions =
      if cross_platform?
        [train_setup, ios_steps_setup, android_steps_setup]
      elsif android?
        [train_setup, android_steps_setup]
      else
        [train_setup, ios_steps_setup]
      end

    instructions.flatten.reduce(:merge)
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
      update_external_app(:ios, ios_store_provider)
      update_external_app(:android, android_store_provider)
    elsif ios?
      update_external_app(:ios, ios_store_provider)
    elsif android?
      update_external_app(:android, android_store_provider)
    else
      raise ArgumentError, "invalid platform"
    end
  end

  def update_external_app(platform, provider)
    app_data = provider&.find_app
    external_app_data = provider&.channel_data

    if external_app_data && latest_external_app&.channel_data != external_app_data
      external_apps.create!(channel_data: external_app_data,
        fetched_at: Time.current,
        platform:,
        default_locale: app_data&.dig(:default_locale))
    end
  end

  def in_draft_mode?
    return draft? if android_store_provider.nil?
    return draft? if draft == false
    set_draft_status!
    draft?
  end

  def set_draft_status!
    update!(draft: draft_check?)
  end

  def latest_external_app
    external_apps.order(fetched_at: :desc).first
  end

  def latest_external_apps
    {
      android: external_apps.where(platform: "android").order(fetched_at: :desc).first,
      ios: external_apps.where(platform: "ios").order(fetched_at: :desc).first
    }
  end

  def refresh_external_app
    RefreshExternalAppJob.perform_later(id)
  end

  def notification_params
    {
      app_name: name,
      app_platform: platform,
      platform_public_img: platform_public_img,
      vcs_public_icon_img: vcs_provider.public_icon_img
    }
  end

  def platform_public_img
    android? ? PUBLIC_ANDROID_ICON : PUBLIC_IOS_ICON
  end

  def platform_store_img
    android? ? GooglePlayStoreIntegration::PUBLIC_ICON : AppStoreIntegration::PUBLIC_ICON
  end

  private

  def latest_store_build_number
    [
      ios_store_provider&.latest_build_number,
      android_store_provider&.latest_build_number
    ].compact.max
  rescue
    nil
  end

  def initialize_config
    build_config
  end

  def no_trains_are_running
    if trains.running? && bundle_identifier_changed?
      errors.add(:bundle_identifier, "cannot be updated if there are running trains!")
    end
  end

  def ensure_deletable
    errors.add(:trains, "cannot delete an app if there are any releases made from it!") if releases.present?
  end
end
