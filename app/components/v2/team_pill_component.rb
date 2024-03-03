class V2::TeamPillComponent < V2::BaseComponent
  def initialize(team)
    @team = team
  end

  attr_reader :team

  def call
    if team
      render V2::StatusIndicatorPillComponent.new(text: team.name, color: team.color)
    else
      render V2::StatusIndicatorPillComponent.new(text: Accounts::Team::UNKNOWN_TEAM_NAME, color: Accounts::Team::UNKNOWN_TEAM_COLOR)
    end
  end
end
