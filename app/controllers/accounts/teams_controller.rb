class Accounts::TeamsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[create update destroy]

  def create
    @team = current_organization.teams.new(team_params)
    if @team.save
      redirect_to teams_accounts_organization_path(current_organization), notice: "Team created."
    else
      redirect_to teams_accounts_organization_path(current_organization), flash: {error: "There was an error: #{@team.errors.full_messages.to_sentence}"}
    end
  end

  def update
    @team = current_organization.teams.find_by(id: params[:id])
    if @team.update(team_params)
      redirect_to teams_accounts_organization_path(current_organization), notice: "Team was updated."
    else
      redirect_to teams_accounts_organization_path(current_organization), flash: {error: "There was an error: #{@team.errors.full_messages.to_sentence}"}
    end
  end

  def destroy
    @team = current_organization.teams.find_by(id: params[:id])
    if @team.delete
      redirect_to teams_accounts_organization_path(current_organization), notice: "Team was deleted."
    else
      redirect_to teams_accounts_organization_path(current_organization), flash: {error: "There was an error: #{@team.errors.full_messages.to_sentence}"}
    end
  end

  def team_params
    params.require(:accounts_team).permit(:name, :color)
  end
end
