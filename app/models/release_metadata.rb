# == Schema Information
#
# Table name: release_metadata
#
#  id                      :uuid             not null, primary key
#  default_locale          :boolean          default(FALSE)
#  description             :text
#  keywords                :string           default([]), is an Array
#  locale                  :string           not null, indexed => [release_platform_run_id]
#  promo_text              :text
#  release_notes           :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_id              :uuid
#  release_platform_run_id :uuid             indexed, indexed => [locale]
#
class ReleaseMetadata < ApplicationRecord
  has_paper_trail

  belongs_to :release, inverse_of: :release_metadata
  belongs_to :release_platform_run, inverse_of: :release_metadata, optional: true

  IOS_NOTES_MAX_LENGTH = 4000
  ANDROID_NOTES_MAX_LENGTH = 500
  PROMO_TEXT_MAX_LENGTH = 170
  IOS_DENY_LIST = %w[<]
  # NOTE: Refer to https://www.regular-expressions.info/unicode.html for supporting more unicode characters
  IOS_PLAINTEXT_REGEX = /\A(?!.*#{Regexp.union(IOS_DENY_LIST)})[\p{L}\p{N}\p{P}\p{Sm}\p{Sc}\p{Zs}\p{M}\n]+\z/
  ANDROID_PLAINTEXT_REGEX = /\A[\p{L}\p{N}\p{P}\p{Sm}\p{Sc}\p{Zs}\p{M}\p{Emoji_Presentation}\p{Extended_Pictographic}\n]+\z/
  DEFAULT_LOCALE = "en-US"
  DEFAULT_LANGUAGE = "English (United States)"
  DEFAULT_RELEASE_NOTES = "The latest version contains bug fixes and performance improvements."

  validates :release_notes,
    format: {with: IOS_PLAINTEXT_REGEX, message: :no_special_characters_ios, denied_characters: IOS_DENY_LIST.join(", "), multiline: true},
    if: :ios?
  validates :release_notes,
    format: {with: ANDROID_PLAINTEXT_REGEX, message: :no_special_characters_android, multiline: true},
    if: :android?
  validates :promo_text,
    format: {with: IOS_PLAINTEXT_REGEX, message: :no_special_characters, allow_blank: true, multiline: true},
    length: {maximum: PROMO_TEXT_MAX_LENGTH}
  validates :locale, uniqueness: {scope: :release_platform_run_id}
  validate :notes_length

  delegate :ios?, :android?, to: :release_platform_run

  # NOTE: strip and normalize line endings across various OSes
  normalizes :release_notes, with: ->(notes) { notes.strip.gsub("\r\n", "\n") }

  def self.find_by_id_and_language(id, language, platform)
    locale_tag = AppStores::Localizable.supported_locale_tag(language, platform)
    ReleaseMetadata.find_by(id: id, locale: locale_tag)
  end

  private

  def notes_length
    errors.add(:release_notes, :too_long, max_length: notes_max_length, platform: release_platform_run.platform) if release_notes.length > notes_max_length
  end

  def notes_max_length
    return ANDROID_NOTES_MAX_LENGTH if android?
    return IOS_NOTES_MAX_LENGTH if ios?
    raise ArgumentError, "Invalid platform"
  end
end
