# frozen_string_literal: true

class V2::StatusIndicatorPillComponent < ViewComponent::Base
  BACKGROUND = {
    success: %w[bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300],
    failure: %w[bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300],
  }
  PILL = {
    success: %w[bg-green-500],
    failure: %w[bg-red-500],
  }

  def initialize(status:, text:)
    @status = status
    @text = text
  end

  attr_reader :text

  def pill
    PILL[@status.to_sym].join(" ")
  end

  def background
    BACKGROUND[@status.to_sym].join(" ")
  end
end
