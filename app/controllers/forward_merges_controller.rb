class ForwardMergesController < SignedInApplicationController
  before_action :set_forward_merge

  def cherry_pick
    unless @forward_merge.actionable?
      redirect_back fallback_location: release_path(@forward_merge.release), alert: "Commit cannot be cherry-picked"
      return
    end

    Commit::CherryPickJob.perform_async(@forward_merge.id)
    redirect_back fallback_location: release_path(@forward_merge.release)
  end

  def mark_as_picked
    @forward_merge.update!(status: "manually_picked")
    redirect_back fallback_location: release_path(@forward_merge.release)
  end

  private

  def set_forward_merge
    @forward_merge = ForwardMerge
      .joins(release: {train: {app: :organization}})
      .where(organizations: {id: current_organization.id})
      .find(params[:id])
  end
end
