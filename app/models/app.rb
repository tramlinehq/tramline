# == Schema Information
#
# Table name: apps
#
#  id                :uuid             not null, primary key
#  organization_id   :uuid             not null
#  name              :string           not null
#  description       :string
#  platform          :string           not null
#  bundle_identifier :string           not null
#  build_number      :bigint           not null
#  timezone          :string           not null
#  slug              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class App < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  GOOGLE_PLAY_STORE_URL_TEMPLATE =
    Addressable::Template.new("https://play.google.com/store/apps/details{?query*}")

  belongs_to :organization, class_name: "Accounts::Organization", optional: false
  has_one :config, class_name: "AppConfig", dependent: :destroy
  has_many :integrations, inverse_of: :app, dependent: :destroy
  has_many :trains, class_name: "Releases::Train", dependent: :destroy
  has_many :sign_off_groups, dependent: :destroy

  validate :no_trains_are_running, on: :update
  validates :bundle_identifier, uniqueness: {scope: :organization_id}
  validates :build_number, numericality: {greater_than_or_equal_to: :build_number_was}, on: :update

  enum platform: {android: "android", ios: "ios"}

  accepts_nested_attributes_for :sign_off_groups, allow_destroy: true, reject_if: :reject_sign_off_groups?

  after_initialize :initialize_config, if: :new_record?
  after_initialize :set_default_platform, if: :new_record?
  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true

  delegate :vcs_provider, to: :integrations, allow_nil: true
  delegate :ci_cd_provider, to: :integrations, allow_nil: true
  delegate :notification_provider, to: :integrations, allow_nil: true
  delegate :slack_build_channel_provider, to: :integrations, allow_nil: true

  scope :with_trains, -> { joins(:trains).distinct }

  def runs
    Releases::Train::Run.joins(train: :app).where(train: {app: self})
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
      +""
    end
  end

  def notifications?
    !notification_provider.nil?
  end

  private

  def set_default_platform
    self.platform = App.platforms[:android]
  end

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
