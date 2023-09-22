module Passportable
  extend ActiveSupport::Concern

  included do
    has_many :passports, as: :stampable, dependent: :destroy
  end

  def event_stamp!(reason:, kind:, data: {}, ts: Time.current)
    PassportJob.perform_later(
      id,
      self.class.name,
      reason:,
      kind:,
      message: I18n.t("passport.#{stamp_namespace}.#{reason}_html", **data),
      metadata: data,
      event_timestamp: ts,
      automatic: automatic?,
      author_id: Current.user&.id,
      author_metadata: author_metadata
    )
  end

  def event_stamp_now!(reason:, kind:, data: {})
    PassportJob.perform_now(
      id,
      self.class.name,
      reason:,
      kind:,
      message: I18n.t("passport.#{stamp_namespace}.#{reason}_html", **data),
      metadata: data,
      event_timestamp: Time.current,
      automatic: automatic?,
      author_id: Current.user&.id,
      author_metadata: author_metadata
    )
  end

  def create_stamp!(data: {})
    event_stamp!(reason: :created, kind: :notice, data: data, ts: created_at)
  end

  def stamp_namespace
    self.class.name.underscore
  end

  private

  def author_metadata
    unless automatic?
      {
        name: Current.user.preferred_name || Current.user.full_name,
        full_name: Current.user.full_name,
        role: Current.user.role_for(Current.organization),
        email: Current.user.email
      }
    end
  end

  def automatic?
    Current.user.blank?
  end
end
