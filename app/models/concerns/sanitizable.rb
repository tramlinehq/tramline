module Sanitizable
  extend ActiveSupport::Concern

  private

  def sanitize_commit_messages(array_of_commit_messages, compact_messages: true)
    array_of_commit_messages
      .map { |str| str&.strip }
      .flat_map { |line| compact_messages ? line.split("\n").first : line.split("\n") }
      .map { |line| line.gsub(/\p{Emoji_Presentation}\s*/, "") }
      .map { |line| line.gsub('"', "\\\"") }
      .reject { |line| line =~ /\AMerge|\ACo-authored-by|\A---------/ }
      .compact_blank
      .uniq
  end
end
