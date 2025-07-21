module PatternTokenizer
  extend ActiveSupport::Concern

  # Available tokens for pattern substitution
  AVAILABLE_TOKENS = {
    'train_name' => 'Name of the train (parameterized)',
    'release_version' => 'Version number of the release',
    'release_start_date' => 'Date when the release was started'
  }.freeze

  # Git branch name constraints based on git-check-ref-format
  # See: https://git-scm.com/docs/git-check-ref-format
  INVALID_BRANCH_CHARS = [
    ' ',      # ASCII space
    '~',      # tilde
    '^',      # caret
    ':',      # colon
    '?',      # question mark
    '*',      # asterisk
    '[',      # opening bracket
    ']',      # closing bracket
    '\\',     # backslash
    "\x00",   # null character
    "\x01",   # control characters
    "\x02",
    "\x03",
    "\x04",
    "\x05",
    "\x06",
    "\x07",
    "\x08",
    "\x09",
    "\x0A",
    "\x0B",
    "\x0C",
    "\x0D",
    "\x0E",
    "\x0F",
    "\x10",
    "\x11",
    "\x12",
    "\x13",
    "\x14",
    "\x15",
    "\x16",
    "\x17",
    "\x18",
    "\x19",
    "\x1A",
    "\x1B",
    "\x1C",
    "\x1D",
    "\x1E",
    "\x1F",
    "\x7F"
  ].freeze

  included do
    validate :validate_pattern_characters, if: :has_pattern_field?
    validate :validate_required_tokens, if: :has_pattern_field?
  end

  # Substitute tokens in a pattern string
  def substitute_tokens(pattern, token_values = {})
    return pattern if pattern.blank?

    result = pattern.dup

    AVAILABLE_TOKENS.keys.each do |token|
      placeholder = "{{#{token}}}"
      if result.include?(placeholder) && token_values[token.to_sym]
        result.gsub!(placeholder, token_values[token.to_sym].to_s)
      end
    end

    # Handle strftime patterns if release_start_date is provided
    if token_values[:release_start_date]
      result = token_values[:release_start_date].strftime(result)
    end

    result
  end

  # Get list of tokens used in a pattern
  def tokens_in_pattern(pattern)
    return [] if pattern.blank?

    tokens = []
    AVAILABLE_TOKENS.keys.each do |token|
      placeholder = "{{#{token}}}"
      tokens << token if pattern.include?(placeholder)
    end
    tokens
  end

  # Validate that pattern contains only allowed characters
  def validate_pattern_characters
    pattern = get_pattern_value
    return if pattern.blank?

    # Check for invalid characters
    invalid_chars = INVALID_BRANCH_CHARS.select { |char| pattern.include?(char) }
    if invalid_chars.any?
      readable_chars = invalid_chars.map do |char|
        case char
        when ' '
          'space'
        when "\x00".."\x1F", "\x7F"
          "control character (\\x#{char.ord.to_s(16).upcase.rjust(2, '0')})"
        else
          "'#{char}'"
        end
      end
      errors.add(pattern_field_name, "contains invalid characters for git branch names: #{readable_chars.join(', ')}")
    end

    # Check for patterns that would create invalid branch names
    if pattern.start_with?('/') || pattern.end_with?('/')
      errors.add(pattern_field_name, "cannot start or end with '/'")
    end

    if pattern.include?('//')
      errors.add(pattern_field_name, "cannot contain consecutive slashes '//'")
    end

    if pattern.include?('..')
      errors.add(pattern_field_name, "cannot contain '..'")
    end

    if pattern.start_with?('.') || pattern.end_with?('.') || pattern.include?('/.')
      errors.add(pattern_field_name, "cannot start with '.', end with '.', or contain '/.'")
    end

    if pattern.end_with?('.lock')
      errors.add(pattern_field_name, "cannot end with '.lock'")
    end
  end

  # Validate required tokens based on pattern type
  def validate_required_tokens
    pattern = get_pattern_value
    return if pattern.blank?

    required_tokens = get_required_tokens
    used_tokens = tokens_in_pattern(pattern)

    missing_tokens = required_tokens - used_tokens
    if missing_tokens.any?
      token_list = missing_tokens.map { |token| "{{#{token}}}" }.join(', ')
      errors.add(pattern_field_name, "must contain required tokens: #{token_list}")
    end
  end

  private

  # Override in including class to specify the pattern field name
  def pattern_field_names
    raise NotImplementedError
  end

  # Override in including class to get the pattern value
  def get_pattern_value(pattern_field_name)
    send(pattern_field_name)
  end

  # Override in including class to specify if it has a pattern field
  def has_pattern_field?
    respond_to?(pattern_field_name)
  end
end
