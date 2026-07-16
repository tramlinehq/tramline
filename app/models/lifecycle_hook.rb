# == Schema Information
#
# Table name: lifecycle_hooks
#
#  id                           :uuid             not null, primary key
#  active                       :boolean          default(TRUE), not null, indexed => [train_id, event]
#  auth_secret                  :string
#  auth_type                    :string           default("none"), not null
#  auth_username                :string
#  body_template                :text
#  event                        :string           not null, indexed => [train_id, active]
#  failure_message_template     :text
#  failure_notification_channel :jsonb
#  headers                      :jsonb            not null
#  http_method                  :string           not null
#  name                         :string           not null
#  notify_on_failure            :boolean          default(TRUE), not null
#  static_variables             :jsonb            not null
#  url                          :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  train_id                     :uuid             not null, indexed, indexed => [event, active]
#
class LifecycleHook < ApplicationRecord
  EVENTS = {
    ios_submission_started: "ios_submission_started",
    ios_rollout_started: "ios_rollout_started",
    android_submission_started: "android_submission_started",
    android_rollout_started: "android_rollout_started"
  }.freeze

  HTTP_METHODS = %w[GET POST PATCH PUT DELETE].freeze

  AUTH_TYPES = {
    none: "none",
    basic: "basic",
    bearer: "bearer"
  }.freeze

  SYSTEM_VARIABLES = %w[build_number version platform release_id release_branch release_url].freeze

  belongs_to :train, inverse_of: :lifecycle_hooks

  enum :event, EVENTS
  enum :auth_type, AUTH_TYPES, prefix: :auth

  encrypts :auth_secret

  validates :name, presence: true
  validates :event, presence: true, inclusion: {in: EVENTS.values}
  validates :http_method, presence: true, inclusion: {in: HTTP_METHODS}
  validates :url, presence: true, format: {with: %r{\Ahttps?://\S+\z}, message: :not_http}
  validates :auth_type, presence: true, inclusion: {in: AUTH_TYPES.values}
  validate :auth_credentials_present

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { where(event: event) }

  def available_variables
    custom_vars = static_variables.to_h.keys.map(&:to_s)
    (SYSTEM_VARIABLES + custom_vars).uniq
  end

  def headers_text
    (headers || {}).map { |k, v| "#{k}: #{v}" }.join("\n")
  end

  def static_variables_text
    (static_variables || {}).map { |k, v| "#{k}: #{v}" }.join("\n")
  end

  private

  def auth_credentials_present
    return if auth_none?

    if auth_basic?
      errors.add(:auth_username, :blank) if auth_username.blank?
      errors.add(:auth_secret, :blank) if auth_secret.blank?
    elsif auth_bearer?
      errors.add(:auth_secret, :blank) if auth_secret.blank?
    end
  end
end
