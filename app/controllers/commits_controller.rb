class CommitsController < SignedInApplicationController
  before_action :set_commit

  def backmerge_cherry_pick_instructions
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :backmerge_cherry_pick_instructions }
      end
    end
  end

  private

  def set_commit
    @commit = Commit
      .joins(release: {train: {app: :organization}})
      .where(organizations: {id: current_organization.id})
      .find(params[:id])
  end
end
