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

  NOTES_MAX_LENGTH = 4000
  PLAINTEXT_REGEX = /\A[₹!@#$%^&*()_+\-=\[\]{};':"\\|`,.\/?\s\p{Alnum}\p{P}\p{Zs}\p{Emoji_Presentation}]+\z/
  DEFAULT_LOCALES = ["en-US", "en-GB", "hi-IN", "en-IN"]
  DEFAULT_LOCALE = DEFAULT_LOCALES.first
  DEFAULT_LANGUAGE = "English (United States)"
  DEFAULT_RELEASE_NOTES = "The latest version contains bug fixes and performance improvements."

  validates :release_notes,
    format: {with: PLAINTEXT_REGEX, message: :no_special_characters, multiline: true},
    length: {maximum: NOTES_MAX_LENGTH}
  validates :promo_text,
    format: {with: PLAINTEXT_REGEX, message: :no_special_characters, allow_blank: true, multiline: true},
    length: {maximum: 170}
  validates :locale, uniqueness: {scope: :release_platform_run_id}

  def self.find_by_id_and_language(id, language, platform)
    locale_tag = AppStores::Localizable.supported_locale_tag(language, platform)
    ReleaseMetadata.find_by(id: id, locale: locale_tag)
  end
end
