# == Schema Information
#
# Table name: passports
#
#  id              :uuid             not null, primary key
#  author_metadata :jsonb
#  automatic       :boolean          default(TRUE)
#  event_timestamp :datetime         not null
#  kind            :string           indexed
#  message         :string
#  metadata        :json
#  reason          :string           indexed
#  stampable_type  :string           not null, indexed => [stampable_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author_id       :uuid             indexed
#  stampable_id    :uuid             not null, indexed => [stampable_type]
#
class Passport < ApplicationRecord
  belongs_to :stampable, polymorphic: true
  belongs_to :author, class_name: "Accounts::User", optional: true

  enum kind: {success: "success", error: "error", notice: "notice"}

  validate :appropriate_reason
  validates :kind, presence: true
  validates :reason, presence: true
  validates :stampable_type, presence: true

  TRAMLINE_AUTHOR = "Tramline"
  TRAMLINE_AUTHOR_FULL_NAME = "Tram Line"

  delegate :platform, to: :stampable

  class << self
    alias_method :stamp!, :create!
  end

  def appropriate_reason
    return unless defined?(stampable.class::STAMPABLE_REASONS).eql?("constant")

    if stampable.class::STAMPABLE_REASONS.exclude?(reason)
      errors.add(:reason, "should belong to the stampable!")
    end
  end

  def author_name
    return TRAMLINE_AUTHOR if automatic?
    return if author_id.nil?
    author_metadata[:name] || author.preferred_name || author.full_name
  end

  def author_full_name
    return TRAMLINE_AUTHOR_FULL_NAME if automatic?
    return if author_id.nil?
    author_metadata[:full_name] || author.full_name
  end

  def author_email
    return if automatic? || author_id.nil?
    author_metadata[:email]
  end

  def author_role
    return if automatic? || author_id.nil?
    author_metadata[:role]
  end
end
