class Onboarding::StepComponent < BaseComponent
  def initialize(title:, index:, description:, active: false, completed: false)
    @title = title
    @index = index
    @description = description
    @active = active
    @completed = completed
  end

  attr_reader :title, :index, :description

  def is_active?
    @active
  end

  def is_completed?
    @completed
  end

  def item_classes
    "ml-6 mb-10"
  end

  def point_classes
    "absolute -left-3 flex items-center justify-center w-6 h-6 rounded-full ring-8 ring-white dark:ring-gray-900"
  end
end
