# == Schema Information
#
# Table name: passports
#
#  id             :uuid             not null, primary key
#  stampable_type :string           not null
#  stampable_id   :uuid             not null
#  reason         :string
#  kind           :string
#  message        :string
#  metadata       :json
#  user_id        :uuid
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class Passport < ApplicationRecord
  belongs_to :stampable, polymorphic: true
  belongs_to :user, optional: true

  enum kind: {success: "success", error: "error", notice: "notice"}

  validate :appropriate_reason
  validates :kind, presence: true
  validates :reason, presence: true
  validates :stampable_type, presence: true

  class << self
    alias_method :stamp!, :create!
  end

  def appropriate_reason
    return unless defined?(stampable.class::STAMPABLE_REASONS).eql?("constant")

    if stampable.class::STAMPABLE_REASONS.exclude?(reason)
      errors.add(:reason, "should belong to the stampable!")
    end
  end
end
