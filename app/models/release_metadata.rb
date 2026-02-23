# == Schema Information
#
# Table name: release_metadata
#
#  id                      :uuid             not null, primary key
#  default_locale          :boolean          default(FALSE)
#  description             :text
#  draft_promo_text        :text
#  draft_release_notes     :text
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
  IOS_DESCRIPTION_MAX_LENGTH = 4000
  IOS_KEYWORDS_MAX_LENGTH = 100
  ANDROID_NOTES_MAX_LENGTH = 500
  PROMO_TEXT_MAX_LENGTH = 170
  IOS_DENY_LIST = %w[<]
  # NOTE: Refer to https://www.regular-expressions.info/unicode.html for supporting more unicode characters
  IOS_PLAINTEXT_REGEX = /\A(?!.*#{Regexp.union(IOS_DENY_LIST)})[\p{L}\p{N}\p{P}\p{Sm}\p{Sc}\p{Zs}\p{M}\n]+\z/m
  ANDROID_PLAINTEXT_REGEX = /\A[\p{L}\p{N}\p{P}\p{Sm}\p{Sc}\p{Zs}\p{M}\p{Emoji_Presentation}\p{Extended_Pictographic}\n]+\z/m
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
  validates :description, length: {maximum: IOS_DESCRIPTION_MAX_LENGTH}, if: :ios?
  validate :keywords_length, if: :ios?
  validates :locale, uniqueness: {scope: :release_platform_run_id}
  validate :notes_length

  delegate :ios?, :android?, to: :release_platform_run

  # NOTE: strip and normalize line endings across various OSes
  normalizes :release_notes, with: ->(notes) { notes.strip.gsub("\r\n", "\n") }

  def self.find_by_id_and_language(id, language, platform)
    locale_tag = AppStores::Localizable.supported_locale_tag(language, platform)
    ReleaseMetadata.find_by(id: id, locale: locale_tag)
  end

  def update_and_clear_drafts!(attrs)
    update!(attrs.merge(draft_attrs_to_clear(attrs)))
  end

  # rubocop:disable Rails/SkipsModelValidations
  def save_draft(attrs)
    draft_attrs = draft_attrs_to_save(attrs)
    update_columns(draft_attrs) if draft_attrs.present?
  end
  # rubocop:enable Rails/SkipsModelValidations

  private

  def draft_attrs_to_clear(attrs)
    attrs = attrs.to_h.with_indifferent_access
    {}.tap do |drafts|
      drafts[:draft_release_notes] = nil if attrs.key?(:release_notes)
      drafts[:draft_promo_text] = nil if attrs.key?(:promo_text)
    end
  end

  def draft_attrs_to_save(attrs)
    attrs = attrs.to_h.with_indifferent_access
    db_values = self.class.where(id: id).pick(:release_notes, :promo_text)
    db_release_notes, db_promo_text = db_values || [nil, nil]

    {}.tap do |drafts|
      if attrs.key?(:release_notes) && attrs[:release_notes] != db_release_notes
        drafts[:draft_release_notes] = attrs[:release_notes]
      end

      if attrs.key?(:promo_text) && attrs[:promo_text] != db_promo_text
        drafts[:draft_promo_text] = attrs[:promo_text]
      end
    end
  end

  def notes_length
    if release_notes.length > notes_max_length
      errors.add(:release_notes, :too_long, max_length: notes_max_length, platform: release_platform_run.platform)
    end
  end

  def notes_max_length
    return ANDROID_NOTES_MAX_LENGTH if android?
    return IOS_NOTES_MAX_LENGTH if ios?
    raise ArgumentError, "Invalid platform"
  end

  def keywords_length
    if keywords.join(", ").length > IOS_KEYWORDS_MAX_LENGTH
      errors.add(:keywords, :too_long, count: IOS_KEYWORDS_MAX_LENGTH)
    end
  end
end
