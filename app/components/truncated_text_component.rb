class TruncatedTextComponent < ViewComponent::Base
  attr_reader :original_text

  def initialize(original_text:, truncate_at:)
    @original_text = original_text
    @truncate_at = truncate_at
  end

  def truncated_text
    original_text.truncate(@truncate_at)
  end

  def truncate_required?
    original_text.size > @truncate_at
  end
end
