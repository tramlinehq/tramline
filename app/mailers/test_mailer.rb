class TestMailer < ApplicationMailer
  def verify
    @user = Accounts::User.find(params[:user_id])
    @was_run_at = params[:was_run_at]
    @train_name = params[:train_name]

    mail(to: @user.email, subject: "Train started successfully!")
  end
end
