module Passportable
  def event_stamp!(reason:, kind:, data: {})
    PassportJob.perform_later(
      id,
      self.class.name,
      reason:,
      kind:,
      message: I18n.t("passport.#{stamp_namespace}.#{reason}_html", **data),
      metadata: data,
      event_timestamp: Time.current
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
      event_timestamp: Time.current
    )
  end

  def create_stamp!(data: {})
    event_stamp!(reason: :created, kind: :notice, data: data)
  end

  def stamp_namespace
    self.class.name.underscore
  end
end
