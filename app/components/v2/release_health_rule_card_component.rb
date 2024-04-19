class V2::ReleaseHealthRuleCardComponent < V2::BaseComponent
  def initialize(rule:)
    @rule = rule
  end

  attr_reader :rule
  delegate :release_platform, to: :rule
  delegate :train, :app, to: :release_platform

  def logical_operator_tag(text)
    content_tag(:div, text, class: "text-xs text-secondary uppercase bg-main-100 px-2")
  end
end
