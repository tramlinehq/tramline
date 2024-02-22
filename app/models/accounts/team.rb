# == Schema Information
#
# Table name: teams
#
#  id              :uuid             not null, primary key
#  color           :string           not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null, indexed
#
class Accounts::Team < ApplicationRecord
  has_paper_trail

  belongs_to :organization, inverse_of: :memberships, optional: false
  has_many :memberships, dependent: :nullify

  validates :color, uniqueness: { scope: :organization_id }

  before_create :assign_random_color

  PALETTE = %w[#1A56DB #9061F9 #FF6E4A #5AAA4E #7A6FFF #3A9CA6 #FFB997 #537ABD #E3BBFF #AAD4AA]
  UNKNOWN_TEAM_NAME = "Unknown"
  UNKNOWN_TEAM_COLOR = "#BCBCBC"

  SAMPLE_TEAM_COLOR = { Platform: PALETTE[0],
                        Payments: PALETTE[1],
                        Checkout: PALETTE[2],
                        Support: PALETTE[3],
                        Marketplace: PALETTE[4],
                        Growth: PALETTE[5] }

  def self.sample_team_commits
    { Platform: rand(1..10),
      Payments: rand(1..10),
      Checkout: rand(1..10),
      Support: rand(1..10),
      Marketplace: rand(1..10),
      Growth: rand(1..10) }
  end

  private

  def assign_random_color
    self.color = generate_unique_color
  end

  def generate_unique_color
    organization_colors = Team.where(organization_id: organization_id).pluck(:color)
    available_colors = PALETTE - organization_colors
    if available_colors.empty?
      SecureRandom.hex(6)
    else
      available_colors.sample
    end
  end
end
