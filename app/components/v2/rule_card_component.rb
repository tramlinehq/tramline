class V2::RuleCardComponent < V2::BaseComponent
  def initialize(rule:)
    @rule = rule
  end

  delegate :release_platform, to: :rule
  delegate :train, :app, to: :release_platform

  attr_reader :rule

  def logical_operator_tag(text)
    content_tag(:div, text, class: "text-xs text-main-500 uppercase bg-main-100 px-2")
  end
end
