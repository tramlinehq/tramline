module Passportable
  def event_stamp!(reason:, kind:, data: {})
    PassportJob.perform_later(
      id,
      self.class.name,
      reason:,
      kind:,
      message: I18n.t("passport.#{stamp_namespace}.#{reason}_html", **data),
      metadata: data
    )
  end

  def create_stamp!(data: {})
    event_stamp!(reason: :created, kind: :success, data: data)
  end

  def status_update_stamp!(data: {})
    event_stamp!(
      reason: :status_changed,
      kind: :success,
      data: {from: saved_changes[:status].first, to: status}.merge(data)
    )
  end

  def stamp_namespace
    self.class.name.underscore
  end
end
