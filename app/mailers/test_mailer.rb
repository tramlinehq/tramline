class TestMailer < ApplicationMailer
  def verify
    @user = Accounts::User.find(params[:user_id])
    @was_run_at = params[:was_run_at]
    mail(to: @user.email, subject: "Step ran successfully!")
  end
end
