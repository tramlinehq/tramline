class Onboarding::StepComponent < BaseComponent
  def initialize(title:, description:)
    @title = title
    @description = description
  end

  attr_reader :title, :description
end
