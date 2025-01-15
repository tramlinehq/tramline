class TeamPillComponent < BaseComponent
  def initialize(team)
    @team = team
  end

  attr_reader :team

  def call
    if team
      render BadgeComponent.new(text: team.name, color: team.color)
    else
      render BadgeComponent.new(text: Accounts::Team::UNKNOWN_TEAM_NAME, color: Accounts::Team::UNKNOWN_TEAM_COLOR)
    end
  end
end
