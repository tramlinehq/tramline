module PatternTokenizer
  # Token format: ~token_name~
  # Examples:
  #   Release branch: "release/~releaseVersion~/prod"
  #   Ticket/issues filter: "rel-~releaseStartDate~"
  AVAILABLE_TOKENS = {
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
          value # Assume it's already formatted like "%Y-%m-%d"
        when Date, Time
          value.strftime("%Y-%m-%d")
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

  # included do
  #   validate :validate_pattern_tokens, if: :should_validate_patterns?
  # end

  def substitute_tokens(pattern_string, token_values = {})
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

  def apply_token_format(token, value)
    AVAILABLE_TOKENS[token][:formatter].call(value)
  end

  def should_validate_patterns?
    raise "#{self.class} must implement validatable_pattern_fields method" unless respond_to?(:validatable_pattern_fields)

    validatable_pattern_fields.any? do |_, field_config|
      raise "#{self.class} field_config must have :value key" unless field_config.key?(:value)
      pattern_value = field_config[:value]
      pattern_value.present? && pattern_value.match?(TOKEN_FORMAT)
    end
  end

  def validate_pattern_tokens
    raise "#{self.class} must implement validatable_pattern_fields method" unless respond_to?(:validatable_pattern_fields)

    validatable_pattern_fields.each do |field_name, field_config|
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
