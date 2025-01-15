class LiveRelease::StepComponent < ViewComponent::Base
  renders_many :sub_actions

  def initialize(title:, icon:, subtitle: nil)
    @title = title
    @subtitle = subtitle
    @icon = icon
  end

  attr_reader :title, :subtitle, :icon
end
