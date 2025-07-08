module Sanitizable
  extend ActiveSupport::Concern

  COMMIT_FILTER_PATTERNS = /\AMerge|\ACo-authored-by|\A---------/
  EMOJI_PATTERN = /\p{Emoji_Presentation}\s*/

  private

  def sanitize_commit_messages(array_of_commit_messages, compact_messages: true)
    array_of_commit_messages
      .map { |str| str&.strip }
      .flat_map { |line| compact_messages ? line.split("\n").first : line.split("\n") }
      .map { |line| line.gsub(EMOJI_PATTERN, "") }
      .map { |line| line.gsub('"', "\\\"") }
      .reject { |line| line =~ COMMIT_FILTER_PATTERNS }
      .compact_blank
      .uniq
  end
end
