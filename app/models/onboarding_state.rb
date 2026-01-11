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
end
