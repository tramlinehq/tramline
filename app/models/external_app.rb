# == Schema Information
#
# Table name: external_apps
#
#  id             :uuid             not null, primary key
#  channel_data   :jsonb
#  default_locale :string
#  fetched_at     :datetime         indexed
#  platform       :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  app_id         :uuid             not null, indexed
#

class ExternalApp < ApplicationRecord
  has_paper_trail
  belongs_to :app

  CHANNEL_DATA_SCHEMA = Rails.root.join("config/schema/external_app_channel_data.json")
  validates :channel_data, presence: true, json: {message: ->(errors) { errors }, schema: CHANNEL_DATA_SCHEMA}

  def active_locales
    production_channel_data = channel_data.find { |datum| datum["name"] == "production" }
    return [] if production_channel_data.nil?
    production_channel_data["releases"]&.each_with_object(Set.new) do |release, acc|
      release["localizations"]&.each do |localization|
        locale_data = StoreLocaleData.new(self, localization)
        acc << locale_data if locale_data.supported?
      end
    end
  end

  def ios? = platform == "ios"

  def android? = platform == "android"

  class StoreLocaleData
    def initialize(external_app, localization)
      @external_app = external_app
      @localization = localization
    end

    def supported? = AppStores::Localizable.supported_locale_tag?(locale, @external_app.platform)

    def locale = @localization["language"]

    def description = @localization["description"]

    def whats_new = @localization["whats_new"]

    def keywords = @localization["keywords"]&.split(",")

    def text = @localization["text"]

    def promo_text = @localization["promo_text"]

    def is_default_locale = locale == @external_app.default_locale

    def release_notes
      return text if @external_app.android?
      whats_new
    end

    def to_h
      {
        description:,
        locale:,
        keywords:,
        release_notes:,
        promo_text:,
        default_locale: is_default_locale
      }
    end

    def hash
      [self.class, locale].hash
    end

    def eql?(other) = self.class == other.class && locale == other.locale
  end
end
