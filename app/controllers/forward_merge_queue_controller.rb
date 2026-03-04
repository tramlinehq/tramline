class ForwardMergeQueueController < SignedInApplicationController
  before_action :set_forward_merge_queue

  def cherry_pick
    unless @forward_merge_queue.actionable?
      redirect_back fallback_location: release_path(@forward_merge_queue.release), alert: "Commit cannot be cherry-picked"
      return
    end

    Commit::CherryPickJob.perform_async(@forward_merge_queue.id)
    redirect_back fallback_location: release_path(@forward_merge_queue.release)
  end

  def mark_as_picked
    @forward_merge_queue.update!(status: "manually_picked")
    redirect_back fallback_location: release_path(@forward_merge_queue.release)
  end

  private

  def set_forward_merge_queue
    @forward_merge_queue = ForwardMergeQueue
      .joins(release: {train: {app: :organization}})
      .where(organizations: {id: current_organization.id})
      .find(params[:id])
  end
end
