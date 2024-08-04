class PlayStoreSubmissionsController < SignedInApplicationController
  include StoreSubmittable
  before_action :require_write_access!
  before_action :set_play_store_submission
  before_action :set_release_platform_run

  def set_play_store_submission
    @submission = PlayStoreSubmission.find_by(id: params[:id])
  end
end
