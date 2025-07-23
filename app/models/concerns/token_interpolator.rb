module TokenInterpolator
  DATE_FORMAT = "%Y-%m-%d"
  # Token format: ~token_name~
  # Examples:
  #   Release branch: "release/~releaseVersion~/prod"
  #   Ticket/issues filter: "rel-~releaseStartDate~"
  TOKEN_DEFINITIONS = {
    "trainName" => {
      description: "Name of the train (parameterized)",
      formatter: ->(value) { value.to_s.parameterize }
    },
    "releaseVersion" => {
      description: "Version name (eg. 1.2.3) of the release",
      formatter: ->(value) { value.to_s.strip }
    },
    "releaseStartDate" => {
      description: "Date when the release was started",
      formatter: lambda do |value|
        case value
        when String
          begin
            Date.parse(value).strftime(DATE_FORMAT)
          rescue ArgumentError
            value # Fallback to original if unparseable
          end
        when Date, Time
          value.strftime(DATE_FORMAT)
        else
          value.to_s
        end
      end
    },
    "buildNumber" => {
      description: "Build number for the release",
      formatter: ->(value) { value.to_s.strip }
    }
  }.freeze
  TOKEN_FORMAT = /~([^~]+)~/
  TOKEN_PREFIX = "~"
  TOKEN_SUFFIX = "~"

  def interpolate_tokens(pattern_string, token_values = {})
    return pattern_string if pattern_string.blank?

    result = pattern_string.dup
    token_values.each do |token, value|
      next if value.blank?
      # Apply token-specific formatting if available
      formatted_value = apply_token_format(token.to_s, value)
      token_pattern = /#{TOKEN_PREFIX}#{token}#{TOKEN_SUFFIX}/
      result.gsub!(token_pattern, formatted_value.to_s)
    end
    result
  end

  private

  def apply_token_format(token, value)
    TOKEN_DEFINITIONS[token][:formatter].call(value)
  end

  def validate_tokens?
    raise "#{self.class} must implement token_fields method" unless respond_to?(:token_fields)

    token_fields.any? do |_, field_config|
      raise "#{self.class} field_config must have :value key" unless field_config.key?(:value)
      pattern_value = field_config[:value]
      pattern_value.present? && pattern_value.match?(TOKEN_FORMAT)
    end
  end

  def validate_token_fields
    raise "#{self.class} must implement token_fields method" unless respond_to?(:token_fields)

    token_fields.each do |field_name, field_config|
      raise "#{self.class} field_config for #{field_name} must have :value key" unless field_config.key?(:value)
      raise "#{self.class} field_config for #{field_name} must have :allowed_tokens key" unless field_config.key?(:allowed_tokens)

      pattern_value = field_config[:value]
      allowed_tokens = field_config[:allowed_tokens]

      next if pattern_value.blank? || !pattern_value.match?(TOKEN_FORMAT)

      # Find any ~token~ patterns that don't match the allowed tokens for this field
      all_tokens = pattern_value.scan(TOKEN_FORMAT).flatten
      invalid_tokens = all_tokens - allowed_tokens

      if invalid_tokens.any?
        errors.add(field_name, "contains unknown tokens: #{invalid_tokens.map { |t| "#{TOKEN_PREFIX}#{t}#{TOKEN_SUFFIX}" }.join(", ")}")
      end
    end
  end
end
