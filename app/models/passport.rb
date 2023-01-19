# == Schema Information
#
# Table name: passports
#
#  id              :uuid             not null, primary key
#  event_timestamp :datetime         not null
#  kind            :string           indexed
#  message         :string
#  metadata        :json
#  reason          :string           indexed
#  stampable_type  :string           not null, indexed => [stampable_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  stampable_id    :uuid             not null, indexed => [stampable_type]
#  user_id         :uuid
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
