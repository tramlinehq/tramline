class SignOffsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[approve reject revert]
  before_action :set_step, only: [:approve, :reject, :revert]

  def approve
    @sign_off_group = SignOffGroup.find(params[:sign_off_group_id])
    commit = Releases::Commit.find(params[:commit_id])

    if @sign_off_group.members.include?(current_user)
      @step_sign_off = @step.sign_offs.find_or_create_by(user_id: current_user.id, sign_off_group: @sign_off_group, commit: commit)
      @step_sign_off.update(signed: true)
      redirect_back fallback_location: root_path, notice: "You have signed off on this step"
    else
      redirect_back(fallback_location: root_path, notice: "You are not authorized to sign off on this step.")
    end
  end

  def reject
    @sign_off_group = SignOffGroup.find(params[:sign_off_group_id])
    commit = Releases::Commit.find(params[:commit_id])

    if @sign_off_group.members.include?(current_user)
      @step_sign_off = @step.sign_offs.find_or_create_by(user_id: current_user.id, sign_off_group: @sign_off_group, commit: commit)
      @step_sign_off.update(signed: false)
      redirect_back fallback_location: root_path, notice: "You have rejected on this step"
    else
      redirect_back(fallback_location: root_path, notice: "You are not authorized to sign off on this step.")
    end
  end

  def revert
    @sign_off_group = SignOffGroup.find(params[:sign_off_group_id])
    commit = Releases::Commit.find(params[:commit_id])

    if @sign_off_group.members.include?(current_user)
      @step_sign_off = @step.sign_offs.find_by!(sign_off_group: @sign_off_group, commit: commit)
      @step_run = @step_sign_off.step_run
      @step_sign_off.destroy
      @step_run.reset_approval!
      redirect_back fallback_location: root_path, notice: "You have reverted sign this step"
    else
      redirect_back(fallback_location: root_path, notice: "You are not authorized to sign off on this step.")
    end
  end

  private

  def set_step
    @step = Releases::Step.joins(train: :app).where(trains: {apps: {organization: current_organization}}).friendly.find(params[:step_id])
  end
end
