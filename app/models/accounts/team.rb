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

  before_create :assign_random_color

  private

  def assign_random_color
    self.color = generate_random_color
  end

  def generate_random_color
    "#" + SecureRandom.hex(3)
  end
end
