class Passport < ApplicationRecord
  belongs_to :stampable, polymorphic: true
  belongs_to :user, optional: true

  enum kind: {success: "success", error: "error", notice: "notice"}

  validate :appropriate_reason
  validates :kind, presence: true
  validates :reason, presence: true
  validates :stampable_id, presence: true
  validates :stampable_type, presence: true

  class << self
    alias_method :stamp!, :create!
  end

  def appropriate_reason
    if stampable.class::STAMPABLE_REASONS.exclude?(reason)
      errors.add(:reason, "should belong to the stampable!")
    end
  end
end
