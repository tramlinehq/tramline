class Onboarding::StepComponent < BaseComponent
  def initialize(key:, title:, index:, description:, active: false, completed: false)
    @key = key
    @title = title
    @index = index
    @description = description
    @active = active
    @completed = completed
    @item_classes = "ml-6 mb-10"
    @point_classes = "absolute -left-3 flex items-center justify-center w-6 h-6 rounded-full ring-8 ring-white dark:ring-gray-900"
    @onboarding_state = onboarding_state
  end

  attr_reader :key, :title, :index, :description, :point_classes, :item_classes, :onboarding_state

  def is_active?
    @active
  end

  def is_completed?
    @completed
  end
end
