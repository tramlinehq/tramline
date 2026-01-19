# == Schema Information
#
# Table name: onboarding_states
#
#  id           :uuid             not null, primary key
#  vcs_provider :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  app_id       :uuid             not null, indexed
#
class OnboardingState < ApplicationRecord
  belongs_to :app
  validates :vcs_provider, presence: true, inclusion: { in: ["github", "gitlab", "bitbucket"] }, on: :vcs_provider_setup

  def step_completed?(step)
    send(:"#{step}_completed?")
  end

  # step completion is derived from presence of respective fields/associations
  def vcs_provider_completed?
    vcs_provider.present?
  end

  def connect_vcs_provider_completed?
    app.vcs_provider.present?
  end

  def configure_vcs_provider_completed?
    app.integrations.further_setup_by_category.dig(:version_control, :ready)
  end
end
