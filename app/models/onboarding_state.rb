# == Schema Information
#
# Table name: onboarding_states
#
#  id         :uuid             not null, primary key
#  field_1    :string
#  field_2    :string
#  field_3    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :uuid             not null, indexed
#
class OnboardingState < ApplicationRecord
  belongs_to :app

  def step_completed?(step)
    send(:"#{step}_completed?")
  end

  private

  # step completion is derived from presence of respective fields/associations
  def step_1_completed?
    field_1.present?
  end

  def step_2_completed?
    field_2.present?
  end

  def step_3_completed?
    field_3.present?
  end
end
