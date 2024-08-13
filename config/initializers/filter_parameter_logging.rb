# This is a strict approach to parameter filtering for our logs
# to avoid exposing any PII. So any attributes
# not explicitly allowed below will be filtered out from the logs.
#
# Be sure to restart your server when you modify this file.
module ParameterFiltering
  ALLOWED_ATTRIBUTES = %w[
    sign_up_email
    action
    controller
    created_at
    updated_at
    deleted_at
    limit
  ].freeze

  ALLOWED_REGEX = /(^|_)ids?|#{Regexp.union(ALLOWED_ATTRIBUTES)}/
  # We have to explicitly exclude integer params because
  # the lambda can only filter string params.
  DISALLOWED_INTEGER_PARAMS = []
  SANITIZED_VALUE = "[FILTERED]".freeze

  # Returns the lambda for attributes that are okay to leave in the logs
  def self.filter
    lambda { |key, value| value.replace(SANITIZED_VALUE) if !key.match(ALLOWED_REGEX) && value.is_a?(String) }
  end
end

Rails.application.config.filter_parameters += [*ParameterFiltering::DISALLOWED_INTEGER_PARAMS, ParameterFiltering.filter] unless Rails.env.development?
