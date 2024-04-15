class V2::Rule::PartComponent < V2::BaseComponent
  def initialize(condition_text:, condition_subtitle: nil)
    @condition_text = condition_text
    @condition_subtitle = condition_subtitle
  end

  attr_reader :condition_text, :condition_subtitle
end
