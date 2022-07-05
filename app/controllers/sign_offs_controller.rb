class SignOffsController < SignedInApplicationController
  before_action :set_step, only: [:create, :destroy]

  def create
    @sign_off_group = SignOffGroup.find(params[:sign_off_group_id])
    commit = Releases::Commit.find(params[:commit_id])
    if @sign_off_group.members.include?(current_user)
      @step_sign_off = @step.sign_offs.create!(user_id: current_user.id, sign_off_group: @sign_off_group, signed: true, commit: commit)
      redirect_back fallback_location: root_path, notice: "You have signed off on this step"
    else
      redirect_back(fallback_location: root_path, notice: "You are not authorized to sign off on this step.")
    end
  end

  def destroy
    @sign_off_group = SignOffGroup.find(params[:sign_off_group_id])
    commit = Releases::Commit.find(params[:commit_id])
    @step.sign_offs.where(sign_off_group: @sign_off_group, commit: commit).update(signed: false)
    redirect_back fallback_location: root_path, notice: "You have unsigned this step"
  end

  private

  def set_step
    @step = Releases::Step.joins(train: :app).where(trains: {apps: {organization: current_organization}}).friendly.find(params[:step_id])
  end
end
