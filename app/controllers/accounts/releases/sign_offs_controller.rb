class Accounts::Releases::SignOffsController < SignedInApplicationController
  def create
    @step = Releases::Step.friendly.find(params[:step_id])
    @sign_off_group = SignOffGroup.find(params[:sign_off_group_id])
    if @sign_off_group.sign_off_members.include?(current_user)
      @step_sign_off = @step.sign_offs.create!(user_id: current_user.id, sign_off_group: @sign_off_group, signed: true)
      redirect_back fallback_location: root_path, notice: 'You have signed off on this step'
    else
      redirect_back(fallback_location: root_path, notice: 'You are not authorized to sign off on this step.')
    end
  end
end
