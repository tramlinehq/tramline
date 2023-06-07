# == Schema Information
#
# Table name: release_metadata
#
#  id            :uuid             not null, primary key
#  locale        :string           not null, indexed => [train_run_id]
#  promo_text    :text
#  release_notes :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  train_run_id  :uuid             not null, indexed, indexed => [locale]
#
class ReleaseMetadata < ApplicationRecord
  has_paper_trail

  belongs_to :train_run, class_name: "Releases::Train::Run"

  PLAINTEXT_REGEX = /\A[!@#$%^&*()_+\-=\[\]{};':"\\|,.\/?\s\p{Alnum}\p{P}\p{Zs}\p{Emoji_Presentation}]+\z/

  validates :release_notes, format: {with: PLAINTEXT_REGEX, message: :no_special_characters, multiline: true}, length: {maximum: 4000}
  validates :promo_text, format: {with: PLAINTEXT_REGEX, message: :no_special_characters, allow_blank: true, multiline: true}, length: {maximum: 170}
end
