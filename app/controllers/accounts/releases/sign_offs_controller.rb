class Accounts::Releases::SignOffsController < SignedInApplicationController
  def show
    @step = Releases::Step.find(params[:step_id])
    @step_sign_off = @step.sign_offs.find_by(user_id: current_user.id)
  end

  def create
    @step = Releases::Step.find(params[:step_id])
    @step_sign_off = @step.sign_offs.create(user_id: current_user.id)
  end
end
